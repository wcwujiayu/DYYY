#import "AWMSafeDispatchTimer.h"

static const void *kAWMSafeDispatchTimerSpecificKey = &kAWMSafeDispatchTimerSpecificKey;

@interface AWMSafeDispatchTimer ()
@property (nonatomic, strong, nullable) dispatch_source_t internalTimer;
@property (nonatomic, assign) BOOL resumed;
@property (nonatomic, copy, nullable) dispatch_block_t internalHandler;
@property (nonatomic, strong) dispatch_queue_t synchronizationQueue;
@property (nonatomic, assign, getter=isRunning) BOOL running;
@end

@implementation AWMSafeDispatchTimer

- (instancetype)init {
    self = [super init];
    if (self) {
        _synchronizationQueue = dispatch_queue_create("com.dyyy.safeDispatchTimer", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_synchronizationQueue, kAWMSafeDispatchTimerSpecificKey, (__bridge void *)self, NULL);
    }
    return self;
}

- (void)performOnSynchronizationQueue:(dispatch_block_t)block {
    if (!block || !self.synchronizationQueue) {
        return;
    }

    if (dispatch_get_specific(kAWMSafeDispatchTimerSpecificKey) == (__bridge void *)self) {
        block();
        return;
    }

    dispatch_async(self.synchronizationQueue, block);
}

- (void)startWithInterval:(NSTimeInterval)interval
                   leeway:(NSTimeInterval)leeway
                    queue:(dispatch_queue_t)queue
                 repeats:(BOOL)repeats
                 handler:(dispatch_block_t)handler {
    if (interval <= 0.0) {
        interval = 0.1;
    }
    dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC));
    uint64_t repeatInterval = repeats ? (uint64_t)(interval * NSEC_PER_SEC) : DISPATCH_TIME_FOREVER;
    uint64_t tolerance = leeway > 0 ? (uint64_t)(leeway * NSEC_PER_SEC) : (uint64_t)(0.1 * NSEC_PER_SEC);

    __weak __typeof(self) weakSelf = self;
    [self performOnSynchronizationQueue:^{
      __strong __typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf) {
          return;
      }

      [strongSelf cancelLocked];

      dispatch_queue_t targetQueue = queue ?: dispatch_get_main_queue();
      dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, targetQueue);
      if (!timer) {
          return;
      }

      strongSelf.internalTimer = timer;
      strongSelf.internalHandler = handler;

      dispatch_source_set_timer(timer, startTime, repeatInterval, tolerance);
      dispatch_source_set_event_handler(timer, ^{
        __strong __typeof(weakSelf) innerSelf = weakSelf;
        if (!innerSelf) {
            return;
        }
        dispatch_block_t block = innerSelf.internalHandler;
        if (block) {
            block();
        }
        if (!repeats) {
            [innerSelf cancel];
        }
      });

      if (!strongSelf.resumed) {
          dispatch_resume(timer);
          strongSelf.resumed = YES;
      }

      strongSelf.running = YES;
    }];
}

- (void)cancel {
    __weak __typeof(self) weakSelf = self;
    [self performOnSynchronizationQueue:^{
      __strong __typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf) {
          return;
      }
      [strongSelf cancelLocked];
    }];
}

- (void)cancelLocked {
    if (!self.internalTimer) {
        self.internalHandler = nil;
        self.running = NO;
        return;
    }

    dispatch_source_t timer = self.internalTimer;
    self.internalHandler = nil;
    self.internalTimer = nil;

    dispatch_source_set_event_handler(timer, ^{});

    if (self.resumed) {
        dispatch_source_cancel(timer);
        self.resumed = NO;
    }

    self.running = NO;
}

- (BOOL)isRunning {
    if (dispatch_get_specific(kAWMSafeDispatchTimerSpecificKey) == (__bridge void *)self) {
        return _running;
    }

    dispatch_queue_t queue = self.synchronizationQueue;
    if (!queue) {
        return NO;
    }

    __block BOOL runningState = NO;
    dispatch_sync(queue, ^{
      runningState = self->_running;
    });
    return runningState;
}

- (void)dealloc {
    dispatch_queue_t queue = _synchronizationQueue;
    if (!queue) {
        return;
    }

    // Detect on-queue dealloc before clearing the non-owning specific pointer.
    // Last release can happen while draining synchronizationQueue; dispatch_sync
    // to the same queue would deadlock.
    BOOL onSynchronizationQueue =
        (dispatch_get_specific(kAWMSafeDispatchTimerSpecificKey) == (__bridge void *)self);
    dispatch_queue_set_specific(queue, kAWMSafeDispatchTimerSpecificKey, NULL, NULL);

    // Never dispatch_async([self cancel]) from dealloc: the async block would
    // message a dangling object after destruction (seen as EXC_BAD_ACCESS/PAC
    // on com.dyyy.safeDispatchTimer). Tear down synchronously with raw ivars.
    __block dispatch_source_t timer = nil;
    __block BOOL resumed = NO;
    void (^tearDownLocked)(void) = ^{
      timer = self->_internalTimer;
      resumed = self->_resumed;
      self->_internalHandler = nil;
      self->_internalTimer = nil;
      self->_resumed = NO;
      self->_running = NO;
      if (timer) {
          dispatch_source_set_event_handler(timer, ^{});
      }
    };

    if (onSynchronizationQueue) {
        tearDownLocked();
    } else {
        dispatch_sync(queue, tearDownLocked);
    }

    if (timer && resumed) {
        dispatch_source_cancel(timer);
    }
}

@end
