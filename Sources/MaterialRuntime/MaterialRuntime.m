#import "MaterialRuntime.h"
#import <AppKit/AppKit.h>
#import <dlfcn.h>

@interface CALayer (MRCoreMaterial)
- (void)setRecipeName:(NSString *)recipeName fromBundle:(NSBundle *)bundle;
- (void)setWeighting:(double)weight;
- (void)setReduceTransparencyEnabled:(BOOL)enabled;
@end

static void MRSetError(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"MaterialRecipeViewer" code:1
                                      userInfo:@{NSLocalizedDescriptionKey: message}];
}

static id MRRead(id object, NSString *key) {
    @try { return [object valueForKey:key]; }
    @catch (NSException *exception) { return nil; }
}

static NSDictionary *MRLayerSnapshot(CALayer *layer) {
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
    for (CALayer *child in layer.sublayers) [children addObject:MRLayerSnapshot(child)];
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

- (instancetype)initWithRecipeName:(NSString *)recipeName bundleURL:(NSURL *)bundleURL error:(NSError **)error {
    self = [super init];
    if (!self) return nil;
    static void *framework;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        framework = dlopen("/System/Library/PrivateFrameworks/CoreMaterial.framework/CoreMaterial", RTLD_NOW | RTLD_LOCAL);
    });
    Class layerClass = NSClassFromString(@"MTMaterialLayer");
    if (!framework || !layerClass) {
        MRSetError(error, @"This macOS runtime does not provide MTMaterialLayer.");
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
        _layer.frame = CGRectMake(0, 0, 400, 260);
        [_layer setRecipeName:recipeName fromBundle:_resourceBundle];
        if (!MRRead(_layer, @"_recipeSettings")) {
            MRSetError(error, @"CoreMaterial did not load the recipe settings.");
            return nil;
        }
        if (![self configureWithWeight:1 reduceTransparency:NO error:error]) return nil;
        _runtimeDescription = [NSString stringWithFormat:@"macOS %@ · %@", NSProcessInfo.processInfo.operatingSystemVersionString,
                               NSStringFromClass(_layer.class)];
        return self;
    } @catch (NSException *exception) {
        MRSetError(error, exception.reason ?: exception.name);
        return nil;
    }
}

- (BOOL)configureWithWeight:(double)weight reduceTransparency:(BOOL)reduceTransparency error:(NSError **)error {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    @try {
        [_layer setReduceTransparencyEnabled:reduceTransparency];
        [_layer setWeighting:weight];
        [_layer setNeedsLayout];
        [_layer layoutIfNeeded];
        return YES;
    } @catch (NSException *exception) {
        MRSetError(error, exception.reason ?: exception.name);
        return NO;
    } @finally {
        [CATransaction commit];
    }
}

- (NSDictionary<NSString *, id> *)layerSnapshotWithError:(NSError **)error {
    @try {
        [_layer layoutIfNeeded];
        return MRLayerSnapshot(_layer);
    } @catch (NSException *exception) {
        MRSetError(error, exception.reason ?: exception.name);
        return nil;
    }
}
@end
