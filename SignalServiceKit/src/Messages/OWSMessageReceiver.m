//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageReceiver.h"
#import "AppContext.h"
#import "AppReadiness.h"
#import "NSArray+OWS.h"
#import "NotificationsProtocol.h"
#import "OWSBackgroundTask.h"
#import "OWSBatchMessageProcessor.h"
#import "OWSMessageDecrypter.h"
#import "OWSQueues.h"
#import "OWSStorage.h"
#import "SSKEnvironment.h"
#import "TSAccountManager.h"
#import "TSErrorMessage.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalCoreKit/Threading.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSMessageDecryptJob

+ (NSString *)collection
{
    return @"OWSMessageProcessingJob";
}

- (instancetype)initWithEnvelopeData:(NSData *)envelopeData
{
    OWSAssertDebug(envelopeData);

    self = [super init];
    if (!self) {
        return self;
    }

    _envelopeData = envelopeData;
    _createdAt = [NSDate new];

    return self;
}

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithUniqueId:(NSString *)uniqueId
                       createdAt:(NSDate *)createdAt
                    envelopeData:(NSData *)envelopeData
{
    self = [super initWithUniqueId:uniqueId];

    if (!self) {
        return self;
    }

    _createdAt = createdAt;
    _envelopeData = envelopeData;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    return [super initWithCoder:coder];
}

- (nullable SSKProtoEnvelope *)envelopeProto
{
    NSError *error;
    SSKProtoEnvelope *_Nullable envelope = [SSKProtoEnvelope parseData:self.envelopeData error:&error];
    if (error || envelope == nil) {
        OWSFailDebug(@"failed to parse envelope with error: %@", error);
        return nil;
    }

    return envelope;
}

@end

#pragma mark - Finder

NSString *const OWSMessageDecryptJobFinderExtensionName = @"OWSMessageProcessingJobFinderExtensionName2";
NSString *const OWSMessageDecryptJobFinderExtensionGroup = @"OWSMessageProcessingJobFinderExtensionGroup2";

@implementation OWSMessageDecryptJobFinder

#pragma mark - Dependencies

- (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

#pragma mark -

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    [OWSMessageDecryptJobFinder registerLegacyClasses];

    return self;
}

- (NSString *)databaseExtensionName
{
    return OWSMessageDecryptJobFinderExtensionName;
}

- (NSString *)databaseExtensionGroup
{
    return OWSMessageDecryptJobFinderExtensionGroup;
}

- (OWSMessageDecryptJob *_Nullable)nextJob
{
    // POST GRDB TODO: Remove this queue & finder entirely.
    if (SSKFeatureFlags.storageMode != StorageModeYdb) {
        OWSLogWarn(@"Not processing queue; obsolete.");
        return nil;
    }

    __block OWSMessageDecryptJob *_Nullable job = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        job = [self nextJobWithTransaction:transaction];
    }];
    return job;
}

- (void)addJobForEnvelopeData:(NSData *)envelopeData
{
    [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction *transaction) {
        [self addJobForEnvelopeData:envelopeData transaction:transaction];
    }];
}

- (void)addJobForEnvelopeData:(NSData *)envelopeData transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSMessageDecryptJob *job = [[OWSMessageDecryptJob alloc] initWithEnvelopeData:envelopeData];
    [job anyInsertWithTransaction:transaction];
}

- (void)removeJobWithId:(NSString *)uniqueId
{
    [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction *transaction) {
        OWSMessageDecryptJob *_Nullable job =
            [OWSMessageDecryptJob anyFetchWithUniqueId:uniqueId transaction:transaction];
        if (job) {
            [job anyRemoveWithTransaction:transaction];
        }
    }];
}

- (NSUInteger)queuedJobCount
{
    __block NSUInteger result;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        result = [self queuedJobCountWithTransaction:transaction];
    }];
    return result;
}

- (NSUInteger)queuedJobCountWithTransaction:(SDSAnyReadTransaction *)transaction
{
    return [OWSMessageDecryptJob anyCountWithTransaction:transaction];
}

+ (YapDatabaseView *)databaseExtension
{
    YapDatabaseViewSorting *sorting =
        [YapDatabaseViewSorting withObjectBlock:^NSComparisonResult(YapDatabaseReadTransaction *transaction,
            NSString *group,
            NSString *collection1,
            NSString *key1,
            id object1,
            NSString *collection2,
            NSString *key2,
            id object2) {

            if (![object1 isKindOfClass:[OWSMessageDecryptJob class]]) {
                OWSFailDebug(@"Unexpected object: %@ in collection: %@", [object1 class], collection1);
                return NSOrderedSame;
            }
            OWSMessageDecryptJob *job1 = (OWSMessageDecryptJob *)object1;

            if (![object2 isKindOfClass:[OWSMessageDecryptJob class]]) {
                OWSFailDebug(@"Unexpected object: %@ in collection: %@", [object2 class], collection2);
                return NSOrderedSame;
            }
            OWSMessageDecryptJob *job2 = (OWSMessageDecryptJob *)object2;

            return [job1.createdAt compare:job2.createdAt];
        }];

    YapDatabaseViewGrouping *grouping =
        [YapDatabaseViewGrouping withObjectBlock:^NSString *_Nullable(YapDatabaseReadTransaction *_Nonnull transaction,
            NSString *_Nonnull collection,
            NSString *_Nonnull key,
            id _Nonnull object) {
            if (![object isKindOfClass:[OWSMessageDecryptJob class]]) {
                OWSFailDebug(@"Unexpected object: %@ in collection: %@", object, collection);
                return nil;
            }

            // Arbitrary string - all in the same group. We're only using the view for sorting.
            return OWSMessageDecryptJobFinderExtensionGroup;
        }];

    YapDatabaseViewOptions *options = [YapDatabaseViewOptions new];
    options.allowedCollections =
        [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithObject:[OWSMessageDecryptJob collection]]];

    return [[YapDatabaseAutoView alloc] initWithGrouping:grouping sorting:sorting versionTag:@"1" options:options];
}

+ (void)registerLegacyClasses
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // We've renamed OWSMessageProcessingJob to OWSMessageDecryptJob.
        [NSKeyedUnarchiver setClass:[OWSMessageDecryptJob class] forClassName:[OWSMessageDecryptJob collection]];
    });
}

+ (void)asyncRegisterDatabaseExtension:(OWSStorage *)storage
{
    [self registerLegacyClasses];

    YapDatabaseView *existingView = [storage registeredExtension:OWSMessageDecryptJobFinderExtensionName];
    if (existingView) {
        OWSFailDebug(@"%@ was already initialized.", OWSMessageDecryptJobFinderExtensionName);
        // already initialized
        return;
    }
    [storage asyncRegisterExtension:[self databaseExtension] withName:OWSMessageDecryptJobFinderExtensionName];
}

@end

#pragma mark - Queue Processing

@interface YAPDBMessageDecryptQueue : NSObject

@property (nonatomic, readonly) OWSMessageDecryptJobFinder *finder;
@property (nonatomic) BOOL isDrainingQueue;

- (instancetype)initWithFinder:(OWSMessageDecryptJobFinder *)finder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

#pragma mark -

@implementation YAPDBMessageDecryptQueue

- (instancetype)initWithFinder:(OWSMessageDecryptJobFinder *)finder
{
    OWSSingletonAssert();

    self = [super init];
    if (!self) {
        return self;
    }

    _finder = finder;
    _isDrainingQueue = NO;

    [AppReadiness runNowOrWhenAppDidBecomeReady:^{
        if (CurrentAppContext().isMainApp) {
            [self drainQueue];
        }
    }];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(registrationStateDidChange:)
                                                 name:RegistrationStateDidChangeNotification
                                               object:nil];

    return self;
}

#pragma mark - Singletons

- (OWSMessageDecrypter *)messageDecrypter
{
    OWSAssertDebug(SSKEnvironment.shared.messageDecrypter);

    return SSKEnvironment.shared.messageDecrypter;
}

- (OWSBatchMessageProcessor *)batchMessageProcessor
{
    OWSAssertDebug(SSKEnvironment.shared.batchMessageProcessor);

    return SSKEnvironment.shared.batchMessageProcessor;
}

- (TSAccountManager *)tsAccountManager
{
    OWSAssertDebug(SSKEnvironment.shared.tsAccountManager);

    return SSKEnvironment.shared.tsAccountManager;
}

- (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

#pragma mark - Notifications

- (void)registrationStateDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    [AppReadiness runNowOrWhenAppDidBecomeReady:^{
        if (CurrentAppContext().isMainApp) {
            [self drainQueue];
        }
    }];
}

#pragma mark - Instance methods

- (dispatch_queue_t)serialQueue
{
    static dispatch_queue_t queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("org.whispersystems.message.decrypt", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

- (void)enqueueEnvelopeData:(NSData *)envelopeData
{
    [self.finder addJobForEnvelopeData:envelopeData];
}

- (void)drainQueue
{
    OWSAssertDebug(AppReadiness.isAppReady || CurrentAppContext().isRunningTests);

    // Don't decrypt messages in app extensions.
    if (!CurrentAppContext().isMainApp) {
        return;
    }
    if (!self.tsAccountManager.isRegisteredAndReady) {
        return;
    }

    dispatch_async(self.serialQueue, ^{
        if (self.isDrainingQueue) {
            return;
        }
        self.isDrainingQueue = YES;

        [self drainQueueWorkStep];
    });
}

- (void)drainQueueWorkStep
{
    AssertOnDispatchQueue(self.serialQueue);

    OWSMessageDecryptJob *_Nullable job = [self.finder nextJob];
    if (!job) {
        self.isDrainingQueue = NO;
        OWSLogVerbose(@"Queue is drained.");
        return;
    }

    __block OWSBackgroundTask *_Nullable backgroundTask =
        [OWSBackgroundTask backgroundTaskWithLabelStr:__PRETTY_FUNCTION__];

    [self processJob:job
          completion:^(BOOL success) {
              [self.finder removeJobWithId:job.uniqueId];
              OWSLogVerbose(@"%@ job. %lu jobs left.",
                  success ? @"decrypted" : @"failed to decrypt",
                  (unsigned long)[self.finder queuedJobCount]);
              [self drainQueueWorkStep];
              OWSAssertDebug(backgroundTask);
              backgroundTask = nil;
          }];
}

- (BOOL)wasReceivedByUD:(SSKProtoEnvelope *)envelope
{
    if (!envelope.hasType) {
        OWSFailDebug(@"Envelope is missing type.");
        return NO;
    }
    return (envelope.unwrappedType == SSKProtoEnvelopeTypeUnidentifiedSender && !envelope.hasValidSource);
}

- (void)processJob:(OWSMessageDecryptJob *)job completion:(void (^)(BOOL))completion
{
    AssertOnDispatchQueue(self.serialQueue);
    OWSAssertDebug(job);

    SSKProtoEnvelope *_Nullable envelope = job.envelopeProto;
    if (!envelope) {
        OWSFailDebug(@"Could not parse proto.");
        // TODO: Add analytics.

        [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction *transaction) {
            ThreadlessErrorMessage *errorMessage = [ThreadlessErrorMessage corruptedMessageInUnknownThread];
            [SSKEnvironment.shared.notificationsManager notifyUserForThreadlessErrorMessage:errorMessage
                                                                                transaction:transaction];
        }];

        dispatch_async(self.serialQueue, ^{
            completion(NO);
        });
        return;
    }

    // We use the original envelope for this check;
    // the decryption process might rewrite the envelope.
    BOOL wasReceivedByUD = [self wasReceivedByUD:envelope];

    [self.messageDecrypter decryptEnvelope:envelope
        envelopeData:job.envelopeData
        successBlock:^(OWSMessageDecryptResult *result, SDSAnyWriteTransaction *transaction) {
            OWSAssertDebug(transaction);

            // We persist the decrypted envelope data in the same transaction within which
            // it was decrypted to prevent data loss.  If the new job isn't persisted,
            // the session state side effects of its decryption are also rolled back.
            //
            // NOTE: We use envelopeData from the decrypt result, not job.envelopeData,
            // since the envelope may be altered by the decryption process in the UD case.
            [self.batchMessageProcessor enqueueEnvelopeData:result.envelopeData
                                              plaintextData:result.plaintextData
                                            wasReceivedByUD:wasReceivedByUD
                                                transaction:transaction];

            dispatch_async(self.serialQueue, ^{
                completion(YES);
            });
        }
        failureBlock:^{
            dispatch_async(self.serialQueue, ^{
                completion(NO);
            });
        }];
}

@end

#pragma mark - OWSMessageReceiver

@interface OWSMessageReceiver ()

@property (nonatomic, readonly) YAPDBMessageDecryptQueue *yapProcessingQueue;

@end

#pragma mark -

@implementation OWSMessageReceiver

- (instancetype)init
{
    OWSSingletonAssert();

    self = [super init];
    if (!self) {
        return self;
    }

    OWSMessageDecryptJobFinder *finder = [OWSMessageDecryptJobFinder new];
    YAPDBMessageDecryptQueue *yapProcessingQueue = [[YAPDBMessageDecryptQueue alloc] initWithFinder:finder];

    _yapProcessingQueue = yapProcessingQueue;

    [AppReadiness runNowOrWhenAppDidBecomeReady:^{
        if (CurrentAppContext().isMainApp) {
            [self.yapProcessingQueue drainQueue];
        }
    }];

    return self;
}

#pragma mark - Dependencies

- (SSKMessageDecryptJobQueue *)messageDecryptJobQueue
{
    return SSKEnvironment.shared.messageDecryptJobQueue;
}

#pragma mark - class methods

+ (NSString *)databaseExtensionName
{
    return OWSMessageDecryptJobFinderExtensionName;
}

+ (void)asyncRegisterDatabaseExtension:(OWSStorage *)storage
{
    [OWSMessageDecryptJobFinder asyncRegisterDatabaseExtension:storage];
}

#pragma mark - instance methods

- (void)handleReceivedEnvelopeData:(NSData *)envelopeData
{
    if (envelopeData.length < 1) {
        OWSFailDebug(@"Empty envelope.");
        return;
    }

    // Drop any too-large messages on the floor. Well behaving clients should never send them.
    NSUInteger kMaxEnvelopeByteCount = 250 * 1024;
    if (envelopeData.length > kMaxEnvelopeByteCount) {
        OWSProdError([OWSAnalyticsEvents messageReceiverErrorOversizeMessage]);
        OWSFailDebug(@"Oversize message.");
        return;
    }

    // Take note of any messages larger than we expect, but still process them.
    // This likely indicates a misbehaving sending client.
    NSUInteger kLargeEnvelopeWarningByteCount = 25 * 1024;
    if (envelopeData.length > kLargeEnvelopeWarningByteCount) {
        OWSProdError([OWSAnalyticsEvents messageReceiverErrorLargeMessage]);
        OWSFailDebug(@"Unexpectedly large message.");
    }

    if (SSKFeatureFlags.storageMode != StorageModeYdb) {
        // We *could* use this processing Queue for Yap *and* GRDB
        [self.messageDecryptJobQueue enqueueEnvelopeData:envelopeData];
    } else {
        [self.yapProcessingQueue enqueueEnvelopeData:envelopeData];
        [self.yapProcessingQueue drainQueue];
    }
}

@end

NS_ASSUME_NONNULL_END
