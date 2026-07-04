// Minimal Assets.car extractor using private CoreUI. Usage: carextract <dir-with-Assets.car-bundle> <outdir>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <dlfcn.h>

@interface CUINamedImage : NSObject
- (CGImageRef)image;
- (NSString *)name;
- (double)scale;
@end

@interface CUICatalog : NSObject
- (instancetype)initWithName:(NSString *)name fromBundle:(NSBundle *)bundle;
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (NSArray *)allImageNames;
- (NSArray *)imagesWithName:(NSString *)name;
@end

int main(int argc, char **argv) {
  @autoreleasepool {
    if (argc < 3) { fprintf(stderr, "usage: carextract <bundleDir> <outDir>\n"); return 2; }
    dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_NOW);
    NSString *carPath = [NSString stringWithUTF8String:argv[1]];
    NSString *outDir = [NSString stringWithUTF8String:argv[2]];
    Class cls = NSClassFromString(@"CUICatalog");
    NSError *err = nil;
    CUICatalog *cat = [[cls alloc] initWithURL:[NSURL fileURLWithPath:carPath] error:&err];
    if (!cat) { fprintf(stderr, "failed to open catalog: %s\n", err.description.UTF8String); return 1; }
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:outDir withIntermediateDirectories:YES attributes:nil error:nil];
    int n = 0;
    for (NSString *name in [cat allImageNames]) {
      @try {
        for (CUINamedImage *ni in [cat imagesWithName:name]) {
          @try {
            CGImageRef img = [ni image];
            if (!img) continue;
            double scale = [ni scale];
            NSString *suf = scale > 1 ? [NSString stringWithFormat:@"@%dx", (int)scale] : @"";
            NSString *safe = [name stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
            NSString *fn = [NSString stringWithFormat:@"%@/%@%@.png", outDir, safe, suf];
            NSURL *url = [NSURL fileURLWithPath:fn];
            CGImageDestinationRef d = CGImageDestinationCreateWithURL((__bridge CFURLRef)url, CFSTR("public.png"), 1, NULL);
            if (d) { CGImageDestinationAddImage(d, img, NULL); CGImageDestinationFinalize(d); CFRelease(d); n++; }
          } @catch (NSException *e) { fprintf(stderr, "  skip rendition of %s: %s\n", name.UTF8String, e.reason.UTF8String); }
        }
      } @catch (NSException *e) { fprintf(stderr, "skip %s: %s\n", name.UTF8String, e.reason.UTF8String); }
    }
    fprintf(stderr, "extracted %d renditions to %s\n", n, argv[2]);
  }
  return 0;
}
