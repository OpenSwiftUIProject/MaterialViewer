#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <TargetConditionals.h>
#if !TARGET_OS_WATCH
#import <QuartzCore/QuartzCore.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface MRMaterialRenderer : NSObject
@property(class, nonatomic, readonly) NSURL *systemFrameworkURL;
@property(class, nonatomic, readonly) Class previewLayerClass;
#if TARGET_OS_WATCH
@property(nonatomic, readonly) NSObject *layer;
#else
@property(nonatomic, readonly) CALayer *layer;
#endif
@property(nonatomic, readonly) NSString *runtimeDescription;
@property(nonatomic) BOOL effectEnabled;
- (nullable instancetype)initWithRecipeName:(NSString *)recipeName
                                bundleURL:(NSURL *)bundleURL
                                    error:(NSError **)error;
- (BOOL)configureWithWeight:(double)weight
        reduceTransparency:(BOOL)reduceTransparency
                     error:(NSError **)error;
- (nullable NSDictionary<NSString *, id> *)layerSnapshotWithError:(NSError **)error;
- (BOOL)attachToLayer:(NSObject *)container size:(CGSize)size scale:(CGFloat)scale error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
