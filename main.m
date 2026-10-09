#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <stdint.h>
#include <math.h>

@interface TestViewController : UIViewController
@property(nonatomic,strong) UITextField *address;
@property(nonatomic,strong) UITextField *timeoutField;
@property(nonatomic,strong) UITextField *statusField;
@property(nonatomic,strong) UIButton *runButton;
@property(nonatomic,strong) UITextView *output;
@end

@implementation TestViewController
- (UITextField *)field:(NSString *)placeholder value:(NSString *)value {
    UITextField *field = [[UITextField alloc] init];
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.placeholder = placeholder;
    field.text = value;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [field.heightAnchor constraintEqualToConstant:44].active = YES;
    return field;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"NSURLSession Test";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *note = [[UILabel alloc] init];
    note.numberOfLines = 0;
    note.text = @"GET <Base URL>/vhx\nSuccess: matching status + trimmed UTF-8 body equals ok (case-insensitive).";
    note.font = [UIFont systemFontOfSize:14];
    self.address = [self field:@"https://your-server.example" value:@""];
    self.address.keyboardType = UIKeyboardTypeURL;
    self.timeoutField = [self field:@"Timeout seconds" value:@"5"];
    self.timeoutField.keyboardType = UIKeyboardTypeDecimalPad;
    self.statusField = [self field:@"Expected HTTP status" value:@"200"];
    self.statusField.keyboardType = UIKeyboardTypeNumberPad;
    self.runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.runButton setTitle:@"Run NSURLSession Test" forState:UIControlStateNormal];
    [self.runButton.heightAnchor constraintEqualToConstant:44].active = YES;
    [self.runButton addTarget:self action:@selector(runTest) forControlEvents:UIControlEventTouchUpInside];
    self.output = [[UITextView alloc] init];
    self.output.editable = NO;
    self.output.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.output.text = @"Enter the base URL without a trailing slash.\nThe original status constant is unknown; 200 is the test default.\nThis App permits HTTP through ATS for testing.";
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:
        @[note, self.address, self.timeoutField, self.statusField, self.runButton, self.output]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12]
    ]];
}
- (void)runTest {
    [self.view endEditing:YES];
    NSString *base = self.address.text ?: @"";
    NSScanner *timeoutScanner = [NSScanner scannerWithString:self.timeoutField.text ?: @""];
    NSScanner *statusScanner = [NSScanner scannerWithString:self.statusField.text ?: @""];
    double timeout = 0;
    NSInteger expected = 0;
    NSURL *url = [NSURL URLWithString:[base stringByAppendingString:@"/vhx"]];
    if (!base.length || !url.host.length ||
        !([url.scheme.lowercaseString isEqualToString:@"http"] || [url.scheme.lowercaseString isEqualToString:@"https"]) ||
        ![timeoutScanner scanDouble:&timeout] || !timeoutScanner.isAtEnd ||
        !isfinite(timeout) || timeout <= 0 || timeout > 120 ||
        ![statusScanner scanInteger:&expected] || !statusScanner.isAtEnd || expected < 100 || expected > 599) {
        self.output.text = @"Invalid input. Use an HTTP(S) base URL, timeout in (0,120] seconds, and status 100–599.";
        return;
    }
    self.runButton.enabled = NO;
    self.output.text = [NSString stringWithFormat:@"GET %@\nRequest timeout: %.3fs\nWait limit: %.3fs\nRunning…", url, timeout, timeout + 2];
    // Waiting on a worker leaves the main thread and session delegate queue free.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            __block NSData *receivedData = nil;
            __block NSURLResponse *receivedResponse = nil;
            __block NSError *receivedError = nil;
            __block BOOL success = NO;
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            request.HTTPMethod = @"GET";
            request.timeoutInterval = timeout;
            NSTimeInterval start = NSProcessInfo.processInfo.systemUptime;
            NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    receivedData = data;
                    receivedResponse = response;
                    receivedError = error;
                    NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
                    if (!error && http && http.statusCode == expected && data.length) {
                        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                        success = trimmed != nil && [trimmed caseInsensitiveCompare:@"ok"] == NSOrderedSame;
                    }
                    dispatch_semaphore_signal(semaphore);
                }];
            [task resume];
            long wait = dispatch_semaphore_wait(semaphore,
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 2) * NSEC_PER_SEC)));
            NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime - start;
            NSString *result;
            if (wait) {
                [task cancel];
                // Do not read captured response variables on this path: the callback can still run.
                result = [NSString stringWithFormat:@"RESULT=false\nGET %@\nElapsed: %.3fs\nSemaphore wait timed out; task cancelled.", url, elapsed];
            } else {
                NSHTTPURLResponse *http = [receivedResponse isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)receivedResponse : nil;
                NSString *body = [[NSString alloc] initWithData:receivedData ?: [NSData data] encoding:NSUTF8StringEncoding];
                NSString *preview = body ? [body substringToIndex:MIN(body.length, (NSUInteger)8192)] : @"(Invalid UTF-8)";
                result = [NSString stringWithFormat:
                    @"RESULT=%@\nGET %@\nFinal URL: %@\nElapsed: %.3fs\nHTTP status: %ld (expected %ld)\nBytes: %lu\nError domain: %@\nError code: %ld\nError: %@\nError details: %@\nHeaders: %@\n\nBody preview (up to 8192 UTF-16 units):\n%@",
                    success ? @"true" : @"false", url, receivedResponse.URL.absoluteString ?: @"(none)", elapsed,
                    (long)http.statusCode, (long)expected, (unsigned long)receivedData.length,
                    receivedError.domain ?: @"(none)", (long)receivedError.code,
                    receivedError.localizedDescription ?: @"(none)", receivedError.userInfo ?: @{},
                    http.allHeaderFields ?: @{}, preview];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.output.text = result;
                self.runButton.enabled = YES;
            });
        }
    });
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[[TestViewController alloc] init]];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
