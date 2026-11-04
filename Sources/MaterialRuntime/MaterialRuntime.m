#import "MaterialRuntime.h"
#import <dlfcn.h>

// watchOS implements these Core Animation interfaces but does not expose them in its SDK.
@protocol MRLayer <NSObject>
@property(nonatomic) CGRect frame;
@property(nonatomic) float opacity;
@property(nonatomic) CGFloat cornerRadius;
@property(nonatomic) CGFloat contentsScale;
@property(nonatomic) BOOL masksToBounds;
@property(nonatomic, readonly) NSArray *filters;
@property(nonatomic, readonly) NSArray *sublayers;
@property(nonatomic, readonly) id superlayer;
- (void)addSublayer:(id)layer;
- (void)removeFromSuperlayer;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;
- (void)setRecipeName:(NSString *)recipeName fromBundle:(NSBundle *)bundle;
- (void)setWeighting:(double)weight;
- (void)setReduceTransparencyEnabled:(BOOL)enabled;
@end

@interface NSObject (MRTransaction)
+ (void)begin;
+ (void)setDisableActions:(BOOL)disabled;
+ (void)commit;
@end

static void *MRLoadFramework(void) {
    static void *framework;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        framework = dlopen("/System/Library/PrivateFrameworks/CoreMaterial.framework/CoreMaterial", RTLD_NOW | RTLD_LOCAL);
    });
    return framework;
}

static void MRSetError(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"MaterialRecipeViewer" code:1
                                      userInfo:@{NSLocalizedDescriptionKey: message}];
}

static id MRRead(id object, NSString *key) {
    @try { return [object valueForKey:key]; }
    @catch (NSException *exception) { return nil; }
}

static NSDictionary *MRLayerSnapshot(id<MRLayer> layer) {
    NSMutableArray *filters = [NSMutableArray array];
    for (id filter in layer.filters) {
        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        entry[@"type"] = MRRead(filter, @"type") ?: [filter description];
        NSArray *keys = MRRead(filter, @"inputKeys");
        if (![keys isKindOfClass:NSArray.class]) keys = @[@"inputRadius", @"inputAmount"];
        for (NSString *key in keys) {
            id value = MRRead(filter, key);
            if (value) entry[key] = [NSJSONSerialization isValidJSONObject:@[value]] ? value : [value description];
        }
        [filters addObject:entry];
    }
    NSMutableArray *children = [NSMutableArray array];
    for (id<MRLayer> child in layer.sublayers) [children addObject:MRLayerSnapshot(child)];
    NSMutableDictionary *result = [@{
        @"class": NSStringFromClass(layer.class),
        @"frame": @[@(layer.frame.origin.x), @(layer.frame.origin.y), @(layer.frame.size.width), @(layer.frame.size.height)],
        @"opacity": @(layer.opacity), @"filters": filters, @"sublayers": children
    } mutableCopy];
    for (NSString *key in @[@"scale", @"weighting", @"isReduceTransparencyEnabled"]) {
        id value = MRRead(layer, key);
        if ([value isKindOfClass:NSNumber.class]) result[key] = value;
    }
    return result;
}

@implementation MRMaterialRenderer {
    NSBundle *_resourceBundle;
}

- (void)dealloc {
    [(id<MRLayer>)_layer removeFromSuperlayer];
}

+ (NSURL *)systemFrameworkURL {
    MRLoadFramework();
    Class layerClass = NSClassFromString(@"MTMaterialLayer");
    // Bundle resolves the active Simulator runtime as well as on-device framework resources.
    if (layerClass) return [NSBundle bundleForClass:layerClass].bundleURL;
    return [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/CoreMaterial.framework/" isDirectory:YES];
}

+ (Class)previewLayerClass { return NSClassFromString(@"CALayer"); }

- (BOOL)effectEnabled { return [(id<MRLayer>)_layer opacity] != 0; }

- (void)setEffectEnabled:(BOOL)effectEnabled {
    [(id<MRLayer>)_layer setOpacity:effectEnabled ? 1 : 0];
}

- (BOOL)attachToLayer:(NSObject *)container size:(CGSize)size scale:(CGFloat)scale error:(NSError **)error {
    [NSClassFromString(@"CATransaction") begin];
    [NSClassFromString(@"CATransaction") setDisableActions:YES];
    @try {
        id<MRLayer> layer = (id)_layer;
        if (layer.superlayer != container) {
            [layer removeFromSuperlayer];
            [(id<MRLayer>)container addSublayer:layer];
        }
        layer.frame = (CGRect){CGPointZero, size};
        layer.contentsScale = scale;
        layer.cornerRadius = MIN(24, size.width * 0.1);
        layer.masksToBounds = YES;
        [layer setNeedsLayout];
        [layer layoutIfNeeded];
        return YES;
    } @catch (NSException *exception) {
        MRSetError(error, exception.reason ?: exception.name);
        return NO;
    } @finally {
        [NSClassFromString(@"CATransaction") commit];
    }
}

- (instancetype)initWithRecipeName:(NSString *)recipeName bundleURL:(NSURL *)bundleURL error:(NSError **)error {
    self = [super init];
    if (!self) return nil;
    void *framework = MRLoadFramework();
    Class layerClass = NSClassFromString(@"MTMaterialLayer");
    if (!framework || !layerClass) {
        MRSetError(error, @"This runtime does not provide MTMaterialLayer.");
        return nil;
    }
    @try {
        _resourceBundle = [NSBundle bundleWithURL:bundleURL];
        if (!_resourceBundle || (![_resourceBundle URLForResource:recipeName withExtension:@"materialrecipe"]
                                 && ![_resourceBundle URLForResource:recipeName withExtension:@"descendantrecipe"])) {
            MRSetError(error, @"The preview bundle does not contain the recipe.");
            return nil;
        }
        _layer = [layerClass new];
        for (NSString *name in @[@"setRecipeName:fromBundle:", @"setWeighting:", @"setReduceTransparencyEnabled:"]) {
            if (![_layer respondsToSelector:NSSelectorFromString(name)]) {
                MRSetError(error, [NSString stringWithFormat:@"The current renderer does not support %@.", name]);
                return nil;
            }
        }
        id<MRLayer> layer = (id)_layer;
        layer.frame = CGRectMake(0, 0, 400, 260);
        [layer setRecipeName:recipeName fromBundle:_resourceBundle];
        if (!MRRead(_layer, @"_recipeSettings")) {
            MRSetError(error, @"CoreMaterial did not load the recipe settings.");
            return nil;
        }
        if (![self configureWithWeight:1 reduceTransparency:NO error:error]) return nil;
        _runtimeDescription = [NSString stringWithFormat:@"%@ · %@", NSProcessInfo.processInfo.operatingSystemVersionString,
                               NSStringFromClass(_layer.class)];
        return self;
    } @catch (NSException *exception) {
        MRSetError(error, exception.reason ?: exception.name);
        return nil;
    }
}

- (BOOL)configureWithWeight:(double)weight reduceTransparency:(BOOL)reduceTransparency error:(NSError **)error {
    [NSClassFromString(@"CATransaction") begin];
    [NSClassFromString(@"CATransaction") setDisableActions:YES];
    @try {
        id<MRLayer> layer = (id)_layer;
        [layer setReduceTransparencyEnabled:reduceTransparency];
        [layer setWeighting:weight];
        [layer setNeedsLayout];
        [layer layoutIfNeeded];
        return YES;
    } @catch (NSException *exception) {
        MRSetError(error, exception.reason ?: exception.name);
        return NO;
    } @finally {
        [NSClassFromString(@"CATransaction") commit];
    }
}

- (NSDictionary<NSString *, id> *)layerSnapshotWithError:(NSError **)error {
    @try {
        [(id<MRLayer>)_layer layoutIfNeeded];
        return MRLayerSnapshot((id)_layer);
    } @catch (NSException *exception) {
        MRSetError(error, exception.reason ?: exception.name);
        return nil;
    }
}
@end
