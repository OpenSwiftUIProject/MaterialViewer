#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface MRMaterialRenderer : NSObject
@property(nonatomic, readonly) CALayer *layer;
@property(nonatomic, readonly) NSString *runtimeDescription;
- (nullable instancetype)initWithRecipeName:(NSString *)recipeName
                                bundleURL:(NSURL *)bundleURL
                                    error:(NSError **)error;
- (BOOL)configureWithWeight:(double)weight
        reduceTransparency:(BOOL)reduceTransparency
                     error:(NSError **)error;
- (nullable NSDictionary<NSString *, id> *)layerSnapshotWithError:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
