#import "RimeKitBridge.h"

#import <RimeShim.h>

#include <dispatch/dispatch.h>
#include <string.h>

static NSString * const RimeKitErrorDomain = @"PinyinKeyboard.RimeKitBridge";
static NSInteger const RimeKitErrorInvalidConfiguration = 1;
static NSInteger const RimeKitErrorSetupFailed = 2;
static NSInteger const RimeKitErrorDeploymentFailed = 3;
static NSInteger const RimeKitErrorSessionFailed = 4;

static NSObject *RimeKitGlobalLock(void) {
    static NSObject *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [NSObject new];
    });
    return lock;
}

static RimeApi *RimeKitAPI(void) {
    return rime_get_api();
}

static BOOL RimeKitIsDirectory(NSString *path) {
    BOOL isDirectory = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]
        && isDirectory;
}

static NSString *RimeKitString(const char *value) {
    if (value == NULL) {
        return @"";
    }
    NSString *string = [NSString stringWithUTF8String:value];
    return string ?: @"";
}

@interface RimeKitCandidate ()
@property(nonatomic, copy, readwrite) NSString *text;
@property(nonatomic, copy, readwrite) NSString *annotation;
@property(nonatomic, assign, readwrite) NSInteger index;
@end

@implementation RimeKitCandidate

- (instancetype)initWithText:(NSString *)text
                   annotation:(NSString *)annotation
                        index:(NSInteger)index {
    self = [super init];
    if (self) {
        _text = [text copy];
        _annotation = [annotation copy];
        _index = index;
    }
    return self;
}

@end

@interface RimeKitSnapshot ()
@property(nonatomic, copy, readwrite) NSString *preedit;
@property(nonatomic, copy, readwrite) NSString *rawInput;
@property(nonatomic, copy, readwrite, nullable) NSString *committedText;
@property(nonatomic, copy, readwrite) NSString *schemaID;
@property(nonatomic, copy, readwrite) NSArray<RimeKitCandidate *> *candidates;
@property(nonatomic, assign, readwrite) NSInteger pageIndex;
@property(nonatomic, assign, readwrite) NSInteger pageSize;
@property(nonatomic, assign, readwrite) NSInteger selectedCandidateIndex;
@property(nonatomic, assign, readwrite) BOOL hasNextPage;
@property(nonatomic, assign, readwrite) BOOL composing;
@property(nonatomic, assign, readwrite) BOOL available;
@end

@implementation RimeKitSnapshot

- (instancetype)initWithPreedit:(NSString *)preedit
                        rawInput:(NSString *)rawInput
                  committedText:(NSString *)committedText
                        schemaID:(NSString *)schemaID
                      candidates:(NSArray<RimeKitCandidate *> *)candidates
                       pageIndex:(NSInteger)pageIndex
                        pageSize:(NSInteger)pageSize
            selectedCandidateIndex:(NSInteger)selectedCandidateIndex
                    hasNextPage:(BOOL)hasNextPage
                       composing:(BOOL)composing
                       available:(BOOL)available {
    self = [super init];
    if (self) {
        _preedit = [preedit copy];
        _rawInput = [rawInput copy];
        _committedText = [committedText copy];
        _schemaID = [schemaID copy];
        _candidates = [candidates copy];
        _pageIndex = pageIndex;
        _pageSize = pageSize;
        _selectedCandidateIndex = selectedCandidateIndex;
        _hasNextPage = hasNextPage;
        _composing = composing;
        _available = available;
    }
    return self;
}

@end

@interface RimeKitSession () {
    NSString *_sharedDataPath;
    NSString *_userDataPath;
    NSString *_schemaID;
    RimeSessionId _sessionID;
    RimeKitSnapshot *_currentSnapshot;
}
- (RimeKitSnapshot *)processKeyCode:(int)keyCode;
- (NSString * _Nullable)consumeCommitWithAPI:(RimeApi *)api;
- (RimeKitSnapshot *)snapshotWithCommittedText:(NSString * _Nullable)committedText;
@end

static BOOL RimeKitSetup(RimeApi *api,
                         NSString *sharedDataPath,
                         NSString *userDataPath,
                         NSError **error) {
    static BOOL setupCompleted = NO;

    if (setupCompleted) {
        return YES;
    }

    RimeTraits traits;
    memset(&traits, 0, sizeof(traits));
    RIME_STRUCT_INIT(RimeTraits, traits);
    traits.shared_data_dir = sharedDataPath.UTF8String;
    traits.user_data_dir = userDataPath.UTF8String;
    traits.distribution_name = "PinyinKeyboard";
    traits.distribution_code_name = "PinyinKeyboard";
    traits.distribution_version = "1";
    traits.app_name = "rime.PinyinKeyboard";

    if (api == NULL || api->setup == NULL) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:RimeKitErrorDomain
                                          code:RimeKitErrorSetupFailed
                                      userInfo:@{NSLocalizedDescriptionKey: @"RIME API setup is unavailable"}];
        }
        return NO;
    }

    api->setup(&traits);
    setupCompleted = YES;
    return YES;
}

static BOOL RimeKitEnsureDeployment(RimeApi *api,
                                    NSString *sharedDataPath,
                                    NSString *userDataPath,
                                    NSError **error) {
    NSString *builtDefault = [userDataPath stringByAppendingPathComponent:@"build/default.yaml"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:builtDefault]) {
        return YES;
    }

    if (api == NULL || api->deployer_initialize == NULL || api->deploy == NULL) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:RimeKitErrorDomain
                                          code:RimeKitErrorDeploymentFailed
                                      userInfo:@{NSLocalizedDescriptionKey: @"RIME deployment API is unavailable"}];
        }
        return NO;
    }

    RimeTraits traits;
    memset(&traits, 0, sizeof(traits));
    RIME_STRUCT_INIT(RimeTraits, traits);
    traits.shared_data_dir = sharedDataPath.UTF8String;
    traits.user_data_dir = userDataPath.UTF8String;
    traits.distribution_name = "PinyinKeyboard";
    traits.distribution_code_name = "PinyinKeyboard";
    traits.distribution_version = "1";
    traits.app_name = "rime.PinyinKeyboard";

    api->deployer_initialize(&traits);
    if (!api->deploy()) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:RimeKitErrorDomain
                                          code:RimeKitErrorDeploymentFailed
                                      userInfo:@{NSLocalizedDescriptionKey: @"RIME resource deployment failed"}];
        }
        return NO;
    }
    return YES;
}

@implementation RimeKitSession

- (instancetype)initWithSharedDataPath:(NSString *)sharedDataPath
                           userDataPath:(NSString *)userDataPath
                              schemaID:(NSString *)schemaID {
    self = [super init];
    if (self) {
        _sharedDataPath = [sharedDataPath copy];
        _userDataPath = [userDataPath copy];
        _schemaID = [schemaID copy];
        _sessionID = 0;
        _currentSnapshot = [[RimeKitSnapshot alloc] initWithPreedit:@""
                                                             rawInput:@""
                                                       committedText:nil
                                                             schemaID:_schemaID
                                                           candidates:@[]
                                                            pageIndex:0
                                                             pageSize:0
                                                 selectedCandidateIndex:-1
                                                         hasNextPage:NO
                                                            composing:NO
                                                            available:NO];
    }
    return self;
}

- (BOOL)start:(NSError **)error {
    @synchronized (self) {
        if (_sessionID != 0) {
            return YES;
        }
        if (!RimeKitIsDirectory(_sharedDataPath) || !RimeKitIsDirectory(_userDataPath)) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:RimeKitErrorDomain
                                              code:RimeKitErrorInvalidConfiguration
                                          userInfo:@{NSLocalizedDescriptionKey: @"RIME data directories are unavailable"}];
            }
            return NO;
        }

        RimeApi *api = RimeKitAPI();
        @synchronized (RimeKitGlobalLock()) {
            if (!RimeKitSetup(api, _sharedDataPath, _userDataPath, error)) {
                return NO;
            }
            if (api->initialize == NULL || api->create_session == NULL) {
                if (error != NULL) {
                    *error = [NSError errorWithDomain:RimeKitErrorDomain
                                                  code:RimeKitErrorSetupFailed
                                              userInfo:@{NSLocalizedDescriptionKey: @"RIME initialization API is unavailable"}];
                }
                return NO;
            }
            api->initialize(NULL);
            if (!RimeKitEnsureDeployment(api, _sharedDataPath, _userDataPath, error)) {
                return NO;
            }
            _sessionID = api->create_session();
        }

        if (_sessionID == 0) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:RimeKitErrorDomain
                                              code:RimeKitErrorSessionFailed
                                          userInfo:@{NSLocalizedDescriptionKey: @"RIME session creation failed"}];
            }
            return NO;
        }

        if (_schemaID.length > 0 && api->select_schema != NULL) {
            if (!api->select_schema(_sessionID, _schemaID.UTF8String)) {
                api->destroy_session(_sessionID);
                _sessionID = 0;
                if (error != NULL) {
                    *error = [NSError errorWithDomain:RimeKitErrorDomain
                                                  code:RimeKitErrorSessionFailed
                                              userInfo:@{NSLocalizedDescriptionKey: @"RIME schema selection failed"}];
                }
                return NO;
            }
        }

        _currentSnapshot = [self snapshotWithCommittedText:nil];
        return YES;
    }
}

- (void)stop {
    @synchronized (self) {
        if (_sessionID != 0) {
            RimeApi *api = RimeKitAPI();
            if (api != NULL && api->destroy_session != NULL) {
                api->destroy_session(_sessionID);
            }
            _sessionID = 0;
        }
        _currentSnapshot = [[RimeKitSnapshot alloc] initWithPreedit:@""
                                                             rawInput:@""
                                                       committedText:nil
                                                             schemaID:_schemaID
                                                           candidates:@[]
                                                            pageIndex:0
                                                             pageSize:0
                                                 selectedCandidateIndex:-1
                                                         hasNextPage:NO
                                                            composing:NO
                                                            available:NO];
    }
}

- (BOOL)available {
    @synchronized (self) {
        return _sessionID != 0;
    }
}

- (RimeKitSnapshot *)currentSnapshot {
    @synchronized (self) {
        return _currentSnapshot;
    }
}

- (RimeKitSnapshot *)reset {
    @synchronized (self) {
        RimeApi *api = RimeKitAPI();
        if (_sessionID != 0 && api != NULL && api->clear_composition != NULL) {
            api->clear_composition(_sessionID);
        }
        _currentSnapshot = [self snapshotWithCommittedText:nil];
        return _currentSnapshot;
    }
}

- (RimeKitSnapshot *)processText:(NSString *)text {
    @synchronized (self) {
        if (_sessionID == 0 || text.length == 0) {
            return _currentSnapshot;
        }
        RimeApi *api = RimeKitAPI();
        if (api == NULL || api->process_key == NULL) {
            return _currentSnapshot;
        }
        for (NSUInteger index = 0; index < text.length; index++) {
            [self processKeyCode:(int)[text characterAtIndex:index]];
        }
        return _currentSnapshot;
    }
}

- (RimeKitSnapshot *)processKeyCode:(int)keyCode {
    RimeApi *api = RimeKitAPI();
    if (_sessionID != 0 && api != NULL && api->process_key != NULL) {
        api->process_key(_sessionID, keyCode, 0);
    }
    NSString *commit = [self consumeCommitWithAPI:api];
    _currentSnapshot = [self snapshotWithCommittedText:commit];
    return _currentSnapshot;
}

- (RimeKitSnapshot *)processBackspace {
    @synchronized (self) {
        return [self processKeyCode:0x08];
    }
}

- (RimeKitSnapshot *)processSpace {
    @synchronized (self) {
        return [self processKeyCode:0x20];
    }
}

- (RimeKitSnapshot *)processReturn {
    @synchronized (self) {
        return [self processKeyCode:0x0d];
    }
}

- (RimeKitSnapshot *)selectCandidateAtIndex:(NSInteger)index {
    @synchronized (self) {
        RimeApi *api = RimeKitAPI();
        if (_sessionID != 0 && api != NULL && api->select_candidate_on_current_page != NULL && index >= 0) {
            api->select_candidate_on_current_page(_sessionID, (size_t)index);
        }
        NSString *commit = [self consumeCommitWithAPI:api];
        _currentSnapshot = [self snapshotWithCommittedText:commit];
        return _currentSnapshot;
    }
}

- (NSString *)consumeCommitWithAPI:(RimeApi *)api {
    if (_sessionID == 0 || api == NULL || api->get_commit == NULL) {
        return nil;
    }
    RimeCommit commit;
    memset(&commit, 0, sizeof(commit));
    RIME_STRUCT_INIT(RimeCommit, commit);
    if (!api->get_commit(_sessionID, &commit)) {
        return nil;
    }
    NSString *text = RimeKitString(commit.text);
    if (api->free_commit != NULL) {
        api->free_commit(&commit);
    }
    return text.length == 0 ? nil : text;
}

- (RimeKitSnapshot *)snapshotWithCommittedText:(NSString *)committedText {
    RimeApi *api = RimeKitAPI();
    if (_sessionID == 0 || api == NULL) {
        return [[RimeKitSnapshot alloc] initWithPreedit:@""
                                               rawInput:@""
                                         committedText:committedText
                                               schemaID:_schemaID
                                             candidates:@[]
                                              pageIndex:0
                                               pageSize:0
                                   selectedCandidateIndex:-1
                                           hasNextPage:NO
                                              composing:NO
                                              available:NO];
    }

    NSString *preedit = @"";
    NSString *rawInput = api->get_input != NULL ? RimeKitString(api->get_input(_sessionID)) : @"";
    NSString *schemaID = _schemaID;
    NSArray<RimeKitCandidate *> *candidates = @[];
    NSInteger pageIndex = 0;
    NSInteger pageSize = 0;
    NSInteger selectedIndex = -1;
    BOOL hasNextPage = NO;
    BOOL composing = rawInput.length > 0;

    RimeContext context;
    memset(&context, 0, sizeof(context));
    RIME_STRUCT_INIT(RimeContext, context);
    if (api->get_context != NULL && api->get_context(_sessionID, &context)) {
        preedit = RimeKitString(context.composition.preedit);
        pageIndex = context.menu.page_no;
        pageSize = context.menu.page_size;
        selectedIndex = context.menu.highlighted_candidate_index;
        hasNextPage = !context.menu.is_last_page;
        composing = context.composition.length > 0 || rawInput.length > 0;

        NSMutableArray<RimeKitCandidate *> *items = [NSMutableArray array];
        for (int index = 0; index < context.menu.num_candidates; index++) {
            RimeCandidate candidate = context.menu.candidates[index];
            [items addObject:[[RimeKitCandidate alloc] initWithText:RimeKitString(candidate.text)
                                                        annotation:RimeKitString(candidate.comment)
                                                             index:index]];
        }
        candidates = [items copy];
        if (api->free_context != NULL) {
            api->free_context(&context);
        }
    }

    RimeStatus status;
    memset(&status, 0, sizeof(status));
    RIME_STRUCT_INIT(RimeStatus, status);
    if (api->get_status != NULL && api->get_status(_sessionID, &status)) {
        NSString *reportedSchema = RimeKitString(status.schema_id);
        if (reportedSchema.length > 0) {
            schemaID = reportedSchema;
        }
        if (api->free_status != NULL) {
            api->free_status(&status);
        }
    }

    return [[RimeKitSnapshot alloc] initWithPreedit:preedit
                                           rawInput:rawInput
                                     committedText:committedText
                                           schemaID:schemaID
                                         candidates:candidates
                                          pageIndex:pageIndex
                                           pageSize:pageSize
                               selectedCandidateIndex:selectedIndex
                                       hasNextPage:hasNextPage
                                          composing:composing
                                          available:YES];
}

@end
