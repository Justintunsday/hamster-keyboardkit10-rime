#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RimeKitCandidate : NSObject
@property(nonatomic, copy, readonly) NSString *text;
@property(nonatomic, copy, readonly) NSString *annotation;
@property(nonatomic, assign, readonly) NSInteger index;

- (instancetype)initWithText:(NSString *)text
                   annotation:(NSString *)annotation
                        index:(NSInteger)index;
@end

@interface RimeKitSnapshot : NSObject
@property(nonatomic, copy, readonly) NSString *preedit;
@property(nonatomic, copy, readonly) NSString *rawInput;
@property(nonatomic, copy, readonly, nullable) NSString *committedText;
@property(nonatomic, copy, readonly) NSString *schemaID;
@property(nonatomic, copy, readonly) NSArray<RimeKitCandidate *> *candidates;
@property(nonatomic, assign, readonly) NSInteger pageIndex;
@property(nonatomic, assign, readonly) NSInteger pageSize;
@property(nonatomic, assign, readonly) NSInteger selectedCandidateIndex;
@property(nonatomic, assign, readonly) BOOL hasNextPage;
@property(nonatomic, assign, readonly) BOOL composing;
@property(nonatomic, assign, readonly) BOOL available;

- (instancetype)initWithPreedit:(NSString *)preedit
                        rawInput:(NSString *)rawInput
                  committedText:(NSString * _Nullable)committedText
                        schemaID:(NSString *)schemaID
                      candidates:(NSArray<RimeKitCandidate *> *)candidates
                       pageIndex:(NSInteger)pageIndex
                        pageSize:(NSInteger)pageSize
            selectedCandidateIndex:(NSInteger)selectedCandidateIndex
                    hasNextPage:(BOOL)hasNextPage
                       composing:(BOOL)composing
                       available:(BOOL)available;
@end

/// Minimal public RIME session boundary. The class owns only librime state.
/// Resource installation and keyboard proxy writes stay outside this bridge.
@interface RimeKitSession : NSObject
- (instancetype)initWithSharedDataPath:(NSString *)sharedDataPath
                           userDataPath:(NSString *)userDataPath
                              schemaID:(NSString *)schemaID;

- (BOOL)start:(NSError * _Nullable * _Nullable)error;
- (void)stop;
- (RimeKitSnapshot *)currentSnapshot;
- (RimeKitSnapshot *)reset;
- (RimeKitSnapshot *)processText:(NSString *)text;
- (RimeKitSnapshot *)processBackspace;
- (RimeKitSnapshot *)processSpace;
- (RimeKitSnapshot *)processReturn;
- (RimeKitSnapshot *)selectCandidateAtIndex:(NSInteger)index;

@property(nonatomic, assign, readonly) BOOL available;
@end

NS_ASSUME_NONNULL_END
