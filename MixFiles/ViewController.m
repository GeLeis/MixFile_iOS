//
//  ViewController.m
//  MixFiles
//
//  Created by gelei on 2019/12/12.
//  Copyright © 2019 gelei. All rights reserved.
//

#import "ViewController.h"
#import <Masonry/Masonry.h>
#import "DocTableCell.h"
#import "NSString+JCRegexHelper.h"
#import <AppKit/NSWorkspace.h>
#import "MBProgressHUD/MBProgressHUD.h"
#import <ReactiveObjC/ReactiveObjC.h>
#import "MFSwitchView.h"

#define kTMPREPLACE1 @"GELEI_MIXFILE_RANDOM_kTEMPLATE1"
#define kTMPREPLACE2 @"GELEI_MIXFILE_RANDOM__kTEMPLATE2"

static NSString *identifier = @"mixfile";
/** 注释的正则,包括注释前的空格,注释后的空白符 */
static NSString *kRegOfNote = @"[\\t ]*((?<!:)\\/\\/.*|\\/\\*(\\s|.)*?\\*\\/)\\s?";
//实现方法匹配规则,要求方法最后一个括号顶在最前面
static NSString *kRegOfImpMethod = @"[\\-\\+]\\s?\\([\\s\\S]*?\\{[\\s\\S]*?\\n\\}";
//匹配实现方法的第一行
static NSString *kRegOfImpMethodFirstRow = @"\\n[\\-\\+]\\s?\\(((?!(\\[|\\]|;))[\\s\\S])*?\\{";
//声明方法匹配规则
static NSString *kRegOfmethod = @"[\\-\\+]\\s?\\([\\s\\S]*?;";
//属性匹配规则
static NSString *kRegOfProp = @"@property[\\s\\S]*?;";
/** Complile File */
static NSString *kRegOfCompileFile = @"[\\t ]*.* \\/\\* .*\\.(m|c) in Sources \\*\\/";
//编译文件区域
static NSString *kRegOfPBXSourceBuildPhase = @"\\/\\* Begin PBXSourcesBuildPhase section \\*\\/[\\s\\S]*?\\/\\* End PBXSourcesBuildPhase section \\*\\/";
//文件索引区域
static NSString *kRegOfPBXFileReference = @"\\/\\* Begin PBXFileReference section \\*\\/[\\s\\S]*?\\/\\* End PBXFileReference section \\*\\/";
//类名正则,也只需要匹配类名,不包括扩展,分类,这些与类名是强相关的,只需要知道有哪些类名更改了,不符合规则的不管,因为只做类名的修改,没必要全覆盖
static NSString *kRegOfClass = @"@interface .* :";


@interface ViewController ()<NSTableViewDelegate,NSTableViewDataSource>
/** 选中文件路径 */
@property (nonatomic, strong) NSMutableArray<NSString *> *urls;
/** 项目.xcodeproj路径 */
@property (nonatomic, copy) NSString *rootUrl;
/** 项目根目录路径 */
@property (nonatomic, copy) NSString *projectUrl;
///选择目录按钮
@property (nonatomic, strong) NSButton *addBtn;
/** 重新选择 */
@property (nonatomic, strong) NSButton *cleanBtn;
/** 是否混合属性 */
@property (nonatomic, strong) MFSwitchView *mixPropView;
/** 是否混合方法 */
@property (nonatomic, strong) MFSwitchView *mixMethodView;
/** 混合import */
@property (nonatomic, strong) MFSwitchView *mixImportView;
/** 删除注释 */
@property (nonatomic, strong) MFSwitchView *deleteNoteView;
/** 打乱编译顺序 */
@property (nonatomic, strong) MFSwitchView *mixCompileView;
/** 文件添加前缀同时文件中的类也会添加添加前缀,文件名制作import导入,实际调用是类名相关 */
@property (nonatomic, strong) MFSwitchView *filePrefixView;
/** 文件前缀开关 */
@property (nonatomic, strong) MFSwitchView *classPrefixView;
/** 实现方法代码插入 */
@property (nonatomic, strong) MFSwitchView *insertCodeView;

//测试3
@property (nonatomic, strong) NSButton *startMixBtn;
@property (nonatomic, strong) NSTableView *tableview;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
/** 修改的类名@{@"origin_classname":@"current_classname"} */
@property (nonatomic, strong) NSMutableDictionary<NSString *,NSString *> *mixedClasses;
/** 修改的方法名 */
@property (nonatomic, strong) NSMutableDictionary *mixedMethods;
/** 前缀 */
@property (nonatomic, copy) NSString *glFile_prefix;
/** 类前缀 */
@property (nonatomic, copy) NSString *glClass_prefix;
@property (nonatomic, copy) NSString *insertCode;
/** 所有的.h、.m、.c,目前只考虑 */
@property (nonatomic, strong) NSMutableArray *projectAllFiles;
/** 文件扫描过程中过滤的文件、文件夹 */
@property (nonatomic, strong) NSArray *filterDirs;
/** 执行方法插入的过程中过滤的方法 */
@property (nonatomic, strong) NSArray *filterImps;
/** 代码插入过程中需要过滤的文件夹 */
@property (nonatomic, strong) NSArray *inserFilterDirs;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.semaphore = dispatch_semaphore_create(6);
    self.queue = dispatch_queue_create("gl_mixfiles_queue", DISPATCH_QUEUE_CONCURRENT);
    [self setupView];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    self.view.window.title = @"MixFiles_OC";
    self.view.window.restorable = NO;
    [self.view.window setContentSize:NSMakeSize(860, 600)];
}

- (void)setRootUrl:(NSString *)rootUrl {
    _rootUrl = rootUrl;
    NSString *xcodeProName = _rootUrl.lastPathComponent;
    //获取项目目录
    NSString *propath = [rootUrl stringByReplacingOccurrencesOfString:xcodeProName withString:@""];
    if ([propath containsString:@"file://"]) {
        propath = [propath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    }
    if ([propath isEqualToString:_projectUrl]) {
        return;
    }
    _projectUrl = propath;
    [self refreshProjectAllFiles];
}

- (void)refreshProjectAllFiles {
    [self.projectAllFiles removeAllObjects];
    NSError *error = nil;
    //递归获取所有的文件夹及文件
    NSArray *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_projectUrl error:&error];
    if (error) {
        NSLog(@"\nMix Error:\n%@\n",error.description);
    }
    
    for (NSString *filename in filenames) {
        BOOL filter = NO;
        for (NSString *filterStr in self.filterDirs) {
            if ([filename containsString:filterStr]) {
                filter = YES;
                break;
            }
        }
        if (filter) {
            continue;
        }
        NSString *subpath = [_projectUrl stringByAppendingPathComponent:filename];
        BOOL isDir;
        [[NSFileManager defaultManager] fileExistsAtPath:subpath isDirectory:&isDir];
        //判断是否是文件夹
        if (isDir) {
            NSError *error = nil;
            //递归获取所有的文件夹及文件
            NSArray *names = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:subpath error:&error];
            if (error) {
                NSLog(@"\nMix Error:\n%@\n",error.description);
                continue;
            }
            for (NSString *name in names) {
                if ([name hasSuffix:@".m"] ||
                    [name hasSuffix:@".h"] ||
                    [name hasSuffix:@".c"]) {
                    [self.projectAllFiles addObject:[subpath stringByAppendingPathComponent:name]];
                }
            }
        } else if([subpath hasSuffix:@".m"] ||
                  [subpath hasSuffix:@".h"] ||
                  [subpath hasSuffix:@".c"]){
            [self.projectAllFiles addObject:subpath];
        }
    }
}

//添加文件
- (void)addFile {
    [self chooseFiles:^(NSArray<NSURL *> *urls) {
        for (NSURL *url in urls) {
            //这个url是文件的路径,已经加过了过滤掉
            if (![self.urls containsObject:url.absoluteString]) {
                [self.urls addObject:url.absoluteString];
                if ([url.absoluteString hasSuffix:@".xcodeproj"]) {
                    self.rootUrl = url.absoluteString;
                }
            }
        }
        [self.tableview reloadData];
    } multipleSelection:YES];
}
//选择文件
- (void)chooseFiles:(void(^)(NSArray<NSURL *> *urls))completion multipleSelection:(BOOL)MultipleSelection{
    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setCanChooseFiles:YES];//是否能选择文件file

    [panel setCanChooseDirectories:YES];//是否能打开文件夹

    [panel setAllowsMultipleSelection:MultipleSelection];//是否允许多选file

    NSInteger finded = [panel runModal]; //获取panel的响应

    if (finded == NSModalResponseOK) {
        if (completion) {
            completion([panel URLs]);
        }
    } else {
        if (completion) {
            completion(@[]);
        }
    }
}

- (void)cleanFile {
    [self.urls removeAllObjects];
    [self.tableview reloadData];
}


- (void)startMix {
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    //实现方法代码插入
    [self insertCodeInMFile];
    //修改类名
    [self modifyClassPrefix];
    
    //.h、.m文件内容顺序打乱
    [self modifyFileContent];
    
    //Compile Sources、文件名修改等涉及.pbxproj修改的最后执行,因为会涉及到路径修改
    [self handleXcodeprojFile];
    
    NSLog(@"\n\n********\nFinish\n************\nFinish\n*********\n\n");
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [self showTip:@"完成✅"];
}

- (void)insertCodeInMFile {
    if (self.insertCodeView.state == NSControlStateValueOn && self.insertCode.length > 0) {
        for (NSString *fileUrl in self.urls) {
            NSString *path = [fileUrl copy];
            if ([path containsString:@"file://"]) {
                path = [path stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            }
            NSMutableArray *filepaths = [NSMutableArray array];
            BOOL isDir;
            [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
            //判断是否是文件夹
            if (isDir) {
                NSError *error = nil;
                //递归获取所有的文件夹及文件
                NSArray *filenames = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:&error];
                if (error) {
                    NSLog(@"\nMix Error:\n%@\n",error.description);
                    continue;
                }
                for (NSString *filename in filenames) {
                    [filepaths addObject:[path stringByAppendingPathComponent:filename]];
                }
            } else {
                [filepaths addObject:path];
            }
            for (NSString *fileIntactPath in filepaths) {
                if ([fileIntactPath hasSuffix:@".m"]) {
                    [self inserCodeHandle:fileIntactPath];
                }
            }
        }
    }
}

- (void)inserCodeHandle:(NSString *)fileIntactPath {
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    dispatch_async(self.queue, ^{
        NSString *filepath = [fileIntactPath copy];
        //读取
        //文件内容
        NSString *fileContext = [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
        //获取所有实现的方法
        NSMutableArray *methodImps = [NSMutableArray array];
        //方法的实现
        NSArray<NSTextCheckingResult*> *methodImpMathchs = [fileContext matchesWithRegex:kRegOfImpMethod];
        //方法的实现第一行
        NSArray<NSTextCheckingResult*> *methodImpFristRowmatchs = [fileContext matchesWithRegex:kRegOfImpMethodFirstRow];
        
        if (methodImpMathchs.count != methodImpFristRowmatchs.count) {
            NSMutableArray *mathcImps = [NSMutableArray array];
            for (NSTextCheckingResult *checkingresult in methodImpMathchs) {
                [mathcImps addObject:[fileContext substringWithRange:checkingresult.range]];
            }
            NSLog(@"====");
            NSMutableArray *mathcImpFirstRows = [NSMutableArray array];
            for (NSTextCheckingResult *checkingresult in methodImpFristRowmatchs) {
                [mathcImpFirstRows addObject:[fileContext substringWithRange:checkingresult.range]];
            }
            for (int i= 0 ;i < mathcImps.count;i++) {
                if (![mathcImps[i] containsString:mathcImpFirstRows[i]]) {
                    NSLog(@"%d",i);
                }
            }
            NSLog(@"==%@=======\n%@",mathcImps,mathcImpFirstRows);
        }
        if (methodImpMathchs.count != methodImpFristRowmatchs.count) {
            return ;
        }
        for (int i = 0 ; i< methodImpFristRowmatchs.count; i++) {
            NSTextCheckingResult *methodImpFirstRowmatch = methodImpFristRowmatchs[i];
            NSString *methodFirstRow = [fileContext substringWithRange:methodImpFirstRowmatch.range];
            BOOL add = YES;
            //过滤掉懒加载的方法
            if ([methodFirstRow containsString:@"*)"]) {
                NSRange range1 = [methodFirstRow rangeOfString:@"*)"];
                NSRange range2 = [methodFirstRow rangeOfString:@"{"];
                NSString *sel = [methodFirstRow substringWithRange:NSMakeRange(range1.location + range1.length, range2.location - range1.location - range1.length)];
                sel = [sel stringByReplacingOccurrencesOfString:@" " withString:@""];
                NSString *mehtodImpconten = [fileContext substringWithRange:methodImpMathchs[i].range];
                if ([mehtodImpconten containsString:[NSString stringWithFormat:@"if (!_%@) {",sel]] ||
                    [mehtodImpconten containsString:[NSString stringWithFormat:@"if(!_%@) {",sel]] ||
                    [mehtodImpconten containsString:[NSString stringWithFormat:@"if (!_%@){",sel]] ||
                    [mehtodImpconten containsString:[NSString stringWithFormat:@"if(!_%@){",sel]]
                    ) {
                    add = NO;
                }
            }
            if (add) {
                for (NSString *filterImp in self.filterImps) {
                    if ([methodFirstRow containsString:filterImp]) {
                        add = NO;
                        break;
                    }
                }
            }
            if (add) {
                [methodImps addObject:[fileContext substringWithRange:methodImpFirstRowmatch.range]];
            }
        }
        
        for (NSString *methodFirstRow in methodImps) {
            fileContext = [fileContext stringByReplacingOccurrencesOfString:methodFirstRow withString:[NSString stringWithFormat:@"%@\n\t%@",methodFirstRow,self.insertCode]];
        }
        
        //修改:需要设置MixFiles->Targets->MixFiles->Capabilities->AppSandbox->FileAccess->User Selected File 为Read/Write
        //否则writeHandle获取为空
        NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:filepath];
        //将文件字节截短至0,相当于将文件清空,可供文件填写
        [writeHandle truncateFileAtOffset:0];
        NSError *error = nil;
        [writeHandle writeData:[fileContext dataUsingEncoding:NSUTF8StringEncoding] error:&error];
        if (error) {
            NSLog(@"FilePath=%@\nError=%@",filepath,error);
        }
        [writeHandle closeFile];
        dispatch_semaphore_signal(self.semaphore);
    });
}

- (void)modifyClassPrefix {
    if (self.classPrefixView.state == NSControlStateValueOn && self.glClass_prefix.length > 0) {
        NSMutableArray *classNames = [NSMutableArray array];
        for (NSString *fileUrl in self.urls) {
            NSString *path = [fileUrl copy];
            if ([path containsString:@"file://"]) {
                path = [path stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            }
            NSMutableArray *filepaths = [NSMutableArray array];
            BOOL isDir;
            [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
            //判断是否是文件夹
            if (isDir) {
                NSError *error = nil;
                //递归获取所有的文件夹及文件
                NSArray *filenames = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:&error];
                if (error) {
                    NSLog(@"\nMix Error:\n%@\n",error.description);
                    continue;
                }
                for (NSString *filename in filenames) {
                    [filepaths addObject:[path stringByAppendingPathComponent:filename]];
                }
            } else {
                [filepaths addObject:path];
            }
            for (NSString *fileIntactPath in filepaths) {
                if ([fileIntactPath hasSuffix:@".h"] ||
                    [fileIntactPath hasSuffix:@".m"]) {
                    [self scanFileClassPrefix:fileIntactPath classNames:classNames];
                }
            }
        }
        //修改
        [self finalModifClassPrefix:classNames];
        //根据需要去统计修改过的ClassNames
        NSLog(@"\nClassPrefix=%@\nClassNames=\n%@\n",self.classPrefixView,classNames);
    }
}

- (void)scanFileClassPrefix:(NSString *)fileIntactPath classNames:(NSMutableArray *)classNames {
    NSString *fileContext = [NSString stringWithContentsOfFile:fileIntactPath encoding:NSUTF8StringEncoding error:nil];
    NSArray<NSTextCheckingResult*> *classMatchs = [fileContext matchesWithRegex:kRegOfClass];
    for (NSTextCheckingResult *match in classMatchs) {
        //@"@interface .* :"
        NSString *interfaceHeader = [fileContext substringWithRange:match.range];
        interfaceHeader = [interfaceHeader stringByReplacingOccurrencesOfString:@"@interface " withString:@""];
        interfaceHeader = [interfaceHeader stringByReplacingOccurrencesOfString:@" :" withString:@""];
        if (![classNames containsObject:interfaceHeader]) {
            [classNames addObject:interfaceHeader];
        }
    }
}

- (void)finalModifClassPrefix:(NSArray *)classNames {
    for (NSString *filepath in self.projectAllFiles) {
        NSMutableString *fileContext = [NSMutableString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
        for (NSString *classname in classNames) {
            BOOL next = YES;
            NSMutableArray *unableRanges = [NSMutableArray array];
            while (next) {
                [unableRanges removeAllObjects];
                //类名使用中存在的几种形式
                NSArray<NSTextCheckingResult*> *classcontentMatchs = [fileContext matchesWithRegex:classname];
                if (classcontentMatchs.count == 0) {
                    break;
                }
                for (NSTextCheckingResult *classcontentMatch in classcontentMatchs) {
                    //是否跳过本次匹配
                    BOOL flag = NO;
                    for (NSValue *rangeValue in unableRanges) {
                        if (rangeValue.rangeValue.location == classcontentMatch.range.location && rangeValue.rangeValue.length == classcontentMatch.range.length) {
                            flag = YES;
                            break;
                        }
                    }
                    if (flag) {
                        continue;
                    }
                    
                    //跳过包含Classname,但是不符合替换规则的子串
                    //即:前面跟着字符,后面跟着字符或者.h的子串,即子串、import
                    NSString *classcontent = [fileContext substringWithRange:classcontentMatch.range];
                    NSString *beforeFirstStr = [fileContext substringWithRange:NSMakeRange(classcontentMatch.range.location - 1, 1)];
                    NSString *afterFirstStr = @"";
                    if (classcontentMatch.range.location + classcontentMatch.range.length < fileContext.length -2) {
                        afterFirstStr = [fileContext substringWithRange:NSMakeRange(classcontentMatch.range.location + classcontentMatch.range.length , 2)];
                    }
                    
                    if ([beforeFirstStr matchWithRegex:@"[a-zA-Z]"]) {
                        [unableRanges addObject:[NSValue valueWithRange:classcontentMatch.range]];
                        continue;
                    } else if ([afterFirstStr matchWithRegex:@"([a-zA-Z])|(\\.h)"]) {
                        [unableRanges addObject:[NSValue valueWithRange:classcontentMatch.range]];
                        continue;
                    } else {
                        [fileContext replaceOccurrencesOfString:classcontent withString:[NSString stringWithFormat:@"%@%@",self.glClass_prefix,classname] options:NSLiteralSearch range:classcontentMatch.range];
                        break;
                    }
                }
                next = unableRanges.count < classcontentMatchs.count;
            }
        }
        //修改:需要设置MixFiles->Targets->MixFiles->Capabilities->AppSandbox->FileAccess->User Selected File 为Read/Write
        //否则writeHandle获取为空
        NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:filepath];
        //将文件字节截短至0,相当于将文件清空,可供文件填写
        [writeHandle truncateFileAtOffset:0];
        NSError *error = nil;
        [writeHandle writeData:[fileContext dataUsingEncoding:NSUTF8StringEncoding] error:&error];
        if (error) {
            NSLog(@"FilePath=%@\nError=%@",filepath,error);
        }
        [writeHandle closeFile];
    }
}

//处理头文件、实现文件
- (void)handleHeaderAndImpFile:(NSString *)fileIntactPath {
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    dispatch_async(self.queue, ^{
        //读取
        //文件内容
        NSString *fileContext = [NSString stringWithContentsOfFile:fileIntactPath encoding:NSUTF8StringEncoding error:nil];
        fileContext = [self matchContentAndMix:fileContext mFile:[fileIntactPath hasSuffix:@".m"]];
        
        //修改:需要设置MixFiles->Targets->MixFiles->Capabilities->AppSandbox->FileAccess->User Selected File 为Read/Write
        //否则writeHandle获取为空
        NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:fileIntactPath];
        //将文件字节截短至0,相当于将文件清空,可供文件填写
        [writeHandle truncateFileAtOffset:0];
        NSError *error = nil;
        [writeHandle writeData:[fileContext dataUsingEncoding:NSUTF8StringEncoding] error:&error];
        if (error) {
            NSLog(@"FilePath=%@\nError=%@",fileIntactPath,error);
        }
        [writeHandle closeFile];
        dispatch_semaphore_signal(self.semaphore);
    });
}

- (NSString *)modifyFileNames:(NSString *)fileContext {
    NSArray<NSTextCheckingResult*> *fileReferenceMatch = [fileContext matchesWithRegex:kRegOfPBXFileReference];
    NSString *fileReferenceSection = [fileContext substringWithRange:fileReferenceMatch.firstObject.range];
    NSMutableString *tmpFileReference = [NSMutableString stringWithString:fileReferenceSection];
    //防止一遍遍历一遍修改
    NSArray *tmpUlrs = [NSArray arrayWithArray:[self.urls copy]];
    //修改文件名:
    for (NSString *fileUrl in tmpUlrs) {
        NSString *path = [fileUrl copy];
        if ([path containsString:@"file://"]) {
            path = [path stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        }
        NSMutableArray *filepaths = [NSMutableArray array];
        BOOL isDir;
        [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
        //判断是否是文件夹
        if (isDir) {
            NSError *error = nil;
            //递归获取所有的文件夹及文件
            NSArray *filenames = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:&error];
            if (error) {
                NSLog(@"\nMix Error:\n%@\n",error.description);
                continue;
            }
            for (NSString *filename in filenames) {
                [filepaths addObject:[path stringByAppendingPathComponent:filename]];
            }
        } else {
            [filepaths addObject:path];
        }
        for (NSString *fileIntactPath in filepaths) {
            if ([fileIntactPath hasSuffix:@".h"] ||
                [fileIntactPath hasSuffix:@".m"]) {
                [self modifyFileName:fileIntactPath projFileContext:tmpFileReference hFile:[fileIntactPath hasSuffix:@".h"]];
            }
        }
    }
    return [fileContext stringByReplacingOccurrencesOfString:fileReferenceSection withString:tmpFileReference];
}

//修改文件名
- (void)modifyFileName:(NSString *)path projFileContext:(NSMutableString *)projFileContext hFile:(BOOL)hFile {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filename = [path lastPathComponent];
    NSString *prepath = [path stringByReplacingOccurrencesOfString:filename withString:@""];
    //新的文件名
    NSString *newFileName = [NSString stringWithFormat:@"%@%@",self.glFile_prefix,filename];
    NSString *topath = [prepath stringByAppendingString:newFileName];
    NSError *error = nil;
    [fileManager moveItemAtPath:path toPath:topath error:&error];
    if (error) {
        NSLog(@"Error : %@",error);
        return ;
    }
    //文件名修改后,修改列表中的名称
    NSString *orldFileURL = nil;
    NSString *newfileURL = nil;
    for (NSString *fileUrl in self.urls) {
        if ([fileUrl containsString:path]) {
            orldFileURL = fileUrl;
            newfileURL = [fileUrl stringByReplacingOccurrencesOfString:path withString:topath];
            break;
        }
    }
    if (newfileURL) {
        NSInteger index = [self.urls indexOfObject:orldFileURL];
        [self.urls removeObject:orldFileURL];
        [self.urls insertObject:newfileURL atIndex:index];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableview reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        });
    }
    //只要修改了文件,就刷新一下文件合集
    [self refreshProjectAllFiles];
    //替换配置中的文件名
    [projFileContext replaceOccurrencesOfString:filename withString:newFileName options:NSLiteralSearch range:NSMakeRange(0, projFileContext.length)];
    
    
    //对于.h文件,需要修改所有实现文件中对该文件有import的
    if (hFile) {
        for (NSString *impFile in self.projectAllFiles) {
            //文件内容
            NSString *fileContext = [NSString stringWithContentsOfFile:impFile encoding:NSUTF8StringEncoding error:nil];
            fileContext = [fileContext stringByReplacingOccurrencesOfString:filename withString:newFileName];
            //修改:需要设置MixFiles->Targets->MixFiles->Capabilities->AppSandbox->FileAccess->User Selected File 为Read/Write
            //否则writeHandle获取为空
            NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:impFile];
            //将文件字节截短至0,相当于将文件清空,可供文件填写
            [writeHandle truncateFileAtOffset:0];
            NSError *error = nil;
            [writeHandle writeData:[fileContext dataUsingEncoding:NSUTF8StringEncoding] error:&error];
            [writeHandle closeFile];
        }
    }
}

- (void)modifyFileContent {
    BOOL modifyContent = NO;
    if (self.mixPropView.state == NSControlStateValueOn ||
        self.mixMethodView.state == NSControlStateValueOn ||
        self.mixImportView.state == NSControlStateValueOn ||
        self.deleteNoteView.state == NSControlStateValueOn) {
        modifyContent = YES;
    }
    if (!modifyContent) {
        return;
    }
    for (NSString *fileUrl in self.urls) {
        NSString *path = [fileUrl copy];
        if ([path containsString:@"file://"]) {
            path = [path stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        }
        NSMutableArray *filepaths = [NSMutableArray array];
        BOOL isDir;
        [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
        //判断是否是文件夹
        if (isDir) {
            NSError *error = nil;
            //递归获取所有的文件夹及文件
            NSArray *filenames = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:&error];
            if (error) {
                NSLog(@"\nMix Error:\n%@\n",error.description);
                continue;
            }
            for (NSString *filename in filenames) {
                [filepaths addObject:[path stringByAppendingPathComponent:filename]];
            }
        } else {
            [filepaths addObject:path];
        }
        for (NSString *fileIntactPath in filepaths) {
            if ([fileIntactPath hasSuffix:@".h"] ||
                [fileIntactPath hasSuffix:@".m"]) {
                [self handleHeaderAndImpFile:fileIntactPath];
            }
        }
    }
}

//处理.xcodeproj 项目配置
- (void)handleXcodeprojFile {
    //是否需要修改xcodeproj,避免对xcodeproj没必要的读写操作
    BOOL action = NO;
    if (self.mixCompileView.state == NSControlStateValueOn ||
        (self.filePrefixView.state == NSControlStateValueOn && self.glFile_prefix.length > 0)) {
        action = YES;
    }
    if (!action) {
        return;
    }
    NSString *projFilePath = [self.rootUrl copy];
    if (!projFilePath) {
        for (NSString *fileUrl in self.urls) {
            if ([fileUrl containsString:@".xcodeproj"]) {
                projFilePath = [fileUrl copy];
                break;
            }
        }
    }
    if ([projFilePath containsString:@"file://"]) {
        projFilePath = [projFilePath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    }
    projFilePath = [projFilePath stringByAppendingPathComponent:@"project.pbxproj"];
    //文件内容
    NSString *fileContext = [NSString stringWithContentsOfFile:projFilePath encoding:NSUTF8StringEncoding error:nil];
    
    if (self.mixCompileView.state == NSControlStateValueOn) {
        //编译混合,同时修改pbxproj
        fileContext = [self mixCompileFiles:fileContext];
    }
    
    if (self.filePrefixView.state == NSControlStateValueOn && self.glFile_prefix.length > 0) {
        //修改文件名称,同时修改pbxproj
        fileContext = [self modifyFileNames:fileContext];
    }
    
    //修改:需要设置MixFiles->Targets->MixFiles->Capabilities->AppSandbox->FileAccess->User Selected File 为Read/Write
    //否则writeHandle获取为空
    NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:projFilePath];
    //将文件字节截短至0,相当于将文件清空,可供文件填写
    [writeHandle truncateFileAtOffset:0];
    NSError *error = nil;
    [writeHandle writeData:[fileContext dataUsingEncoding:NSUTF8StringEncoding] error:&error];
    if (error) {
        NSLog(@"FilePath=%@\nError=%@",projFilePath,error);
    }
    [writeHandle closeFile];
}

//正则匹配出所有的方法、属性
- (NSString *)matchContentAndMix:(NSString *)content mFile:(BOOL)mFile{
    //删除注释
    if (self.deleteNoteView.state == NSControlStateValueOn) {
        content = [self matchNote:content];
    }
    //混淆 Import
    if (self.mixImportView.state == NSControlStateValueOn) {
        //匹配所有import
        content = [self matchImports:content];
    }
    
    //混淆 属性、方法定义
    content = [self matchPropertiesDeclare:content mFile:mFile];
    return content;
}

- (NSString *)matchNote:(NSString *)content {
    //判断是否需要删除注释,如果删除,需要删掉注释、注释前的空白符、注释后的换行等空白符
    NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:kRegOfNote options:0 error:nil];
    return [regularExpression stringByReplacingMatchesInString:content options:0 range:NSMakeRange(0, content.length) withTemplate:@""];
}

- (NSString *)matchImports:(NSString *)content {
    NSString *reg = @"#import [\"<].*?[\">]";
    NSMutableArray *results = [NSMutableArray array];
    NSArray<NSTextCheckingResult*> *matchs = [content matchesWithRegex:reg];
    for (NSTextCheckingResult *match in matchs) {
        [results addObject:[content substringWithRange:match.range]];
    }
    //打乱
    while (results.count > 1) {
        uint32_t index = arc4random_uniform((uint32_t)(results.count - 1)) + 1;
        NSString *firstStr = results[0];
        NSString *secondStr = results[index];
        content = [content stringByReplacingOccurrencesOfString:firstStr withString:kTMPREPLACE1];
        content = [content stringByReplacingOccurrencesOfString:secondStr withString:kTMPREPLACE2];
        content = [content stringByReplacingOccurrencesOfString:kTMPREPLACE1 withString:secondStr];
        content = [content stringByReplacingOccurrencesOfString:kTMPREPLACE2 withString:firstStr];
        [results removeObjectAtIndex:index];
        [results removeObjectAtIndex:0];
    }
    return content;
}

//属性、方法交换
- (NSString *)matchPropertiesDeclare:(NSString *)content mFile:(BOOL)mFile {
    //获取所有声明的类从@interface\n开始到@end结束
    NSString *reg = @"@interface[\\s\\S]*?@end";
    NSArray<NSTextCheckingResult*> *matchs = [content matchesWithRegex:reg];
    NSMutableArray *results = [NSMutableArray array];
    for (NSTextCheckingResult *match in matchs) {
        [results addObject:[content substringWithRange:match.range]];
    }
    //如果是.m文件,还需要匹配@implementation...@end
    if (mFile) {
        NSString *regOfInterfaceImp = @"@implementation[\\s\\S]*?@end";
        NSArray<NSTextCheckingResult*> *classImpmatchs = [content matchesWithRegex:regOfInterfaceImp];
        for (NSTextCheckingResult *match in classImpmatchs) {
            [results addObject:[content substringWithRange:match.range]];
        }
    }
    //每个model内部,匹配properties、methods,并打乱
    for (NSString *interContent in results) {
        //interContent为每一个类的类容
        //注释
        NSMutableArray<NSTextCheckingResult*> *notematchs = nil;
        
        NSUInteger startLocation = 0;
        NSString *tmpcontent = [interContent copy];
        //如果是类的声明或者是extensio部分,则只会存在property、方法声明,@implementation部分只会存在方法实现部分
        if ([interContent containsString:@"@interface"]) {
            //匹配注释
            notematchs = [NSMutableArray arrayWithArray:[interContent matchesWithRegex:kRegOfNote]];
            
            //获取所有声明的属性
            NSMutableArray *props = [NSMutableArray array];
            
            NSArray<NSTextCheckingResult*> *propmatchs = [interContent matchesWithRegex:kRegOfProp];
            
            for (NSTextCheckingResult *propmatch in propmatchs) {
                NSString *property = @"";
                //匹配属性对应的注释,将属性和对应的注释绑定在一起
                for (NSTextCheckingResult *notematch in notematchs) {
                    if (notematch.range.location < propmatch.range.location && notematch.range.location > startLocation) {
                        property = [property stringByAppendingFormat:@"%@",[interContent substringWithRange:notematch.range]];
                    }
                }
                property = [property stringByAppendingFormat:@"%@\n",[interContent substringWithRange:propmatch.range]];
                [props addObject:property];
                startLocation = propmatch.range.location + propmatch.range.length;
            }
            
            //获取所有声明的方法
            NSMutableArray *methods = [NSMutableArray array];
            NSArray<NSTextCheckingResult*> *methodmatchs = [interContent matchesWithRegex:kRegOfmethod];
            
            for (NSTextCheckingResult *methodmatch in methodmatchs) {
                NSString *method = @"";
                //匹配方法对应的注释,将属性和对应的注释绑定在一起
                for (NSTextCheckingResult *notematch in notematchs) {
                    if (notematch.range.location < methodmatch.range.location && notematch.range.location > startLocation) {
                        method = [method stringByAppendingFormat:@"%@",[interContent substringWithRange:notematch.range]];
                    }
                }
                method = [method stringByAppendingFormat:@"%@\n",[interContent substringWithRange:methodmatch.range]];
                [methods addObject:method];
                startLocation = methodmatch.range.location + methodmatch.range.length;
            }
            
            
            //打乱属性
            while (self.mixPropView.state == NSControlStateValueOn && props.count > 1) {
                uint32_t index = arc4random_uniform((uint32_t)(props.count - 1)) + 1;
                NSString *firstStr = props[0];
                NSString *secondStr = props[index];
                
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:firstStr withString:kTMPREPLACE1];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:secondStr withString:kTMPREPLACE2];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:kTMPREPLACE1 withString:secondStr];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:kTMPREPLACE2 withString:firstStr];
                [props removeObjectAtIndex:index];
                [props removeObjectAtIndex:0];
            }

            //打乱方法声明
            while (self.mixMethodView.state == NSControlStateValueOn && methods.count > 1) {
                uint32_t index = arc4random_uniform((uint32_t)(methods.count - 1)) + 1;
                NSString *firstStr = methods[0];
                NSString *secondStr = methods[index];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:firstStr withString:kTMPREPLACE1];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:secondStr withString:kTMPREPLACE2];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:kTMPREPLACE1 withString:secondStr];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:kTMPREPLACE2 withString:firstStr];
                [methods removeObjectAtIndex:index];
                [methods removeObjectAtIndex:0];
            }
        } else if ([interContent containsString:@"@implementation"]) {
            ////说明是实现类,实现类需要匹配方法实现
            notematchs = [NSMutableArray arrayWithArray:[interContent matchesWithRegex:kRegOfNote]];
            
            //获取所有实现的方法
            NSMutableArray *methodImps = [NSMutableArray array];
            //方法的实现
            NSArray<NSTextCheckingResult*> *methodImpmatchs = [interContent matchesWithRegex:kRegOfImpMethod];
            
            for (NSTextCheckingResult *methodImpmatch in methodImpmatchs) {
                NSString *method = @"";
                //匹配方法对应的注释,将属性和对应的注释绑定在一起
                for (NSTextCheckingResult *notematch in notematchs) {
                    if (notematch.range.location < methodImpmatch.range.location && notematch.range.location > startLocation) {
                        method = [method stringByAppendingFormat:@"%@",[interContent substringWithRange:notematch.range]];
                    }
                }
                method = [method stringByAppendingFormat:@"%@\n",[interContent substringWithRange:methodImpmatch.range]];
                [methodImps addObject:method];
                startLocation = methodImpmatch.range.location + methodImpmatch.range.length;
            }
//            NSLog(@"%@",methodImps);
            //打乱方法实现
            while (self.mixMethodView.state == NSControlStateValueOn && methodImps.count > 1) {
                uint32_t index = arc4random_uniform((uint32_t)(methodImps.count - 1)) + 1;
                NSString *firstStr = methodImps[0];
                NSString *secondStr = methodImps[index];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:firstStr withString:kTMPREPLACE1];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:secondStr withString:kTMPREPLACE2];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:kTMPREPLACE1 withString:secondStr];
                tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:kTMPREPLACE2 withString:firstStr];
                [methodImps removeObjectAtIndex:index];
                [methodImps removeObjectAtIndex:0];
            }
        }
        content = [content stringByReplacingOccurrencesOfString:interContent withString:tmpcontent];
    }
    return content;
}
//打乱编译顺序
- (NSString *)mixCompileFiles:(NSString *)content {
    NSArray<NSTextCheckingResult*> *sectionMatch = [content matchesWithRegex:kRegOfPBXSourceBuildPhase];
    NSString *section = [content substringWithRange:sectionMatch.firstObject.range];
    
    NSString *regOfSources = @"\\/\\* Sources \\*\\/ = \\{[\\s\\S]*?\\};";
    NSArray<NSTextCheckingResult*> *sourcesMatchs = [section matchesWithRegex:regOfSources];
    NSMutableArray<NSString *> *sourcesArr = [NSMutableArray array];
    for (NSTextCheckingResult *sourcesMatch in sourcesMatchs) {
        [sourcesArr addObject:[section substringWithRange:sourcesMatch.range]];
    }
    //遍历每一组/* Sources */ = {}
    for (NSString *sources in sourcesArr) {
        NSString *tmpcontent = [sources copy];
        //kRegOfCompileFile
        NSArray<NSTextCheckingResult*> *fileMatchs = [sources matchesWithRegex:kRegOfCompileFile];
        NSMutableArray *files = [NSMutableArray array];
        for (NSTextCheckingResult *filematch in fileMatchs) {
            [files addObject:[sources substringWithRange:filematch.range]];
        }
        
        //打乱方法实现
        while (files.count > 1) {
            uint32_t index = arc4random_uniform((uint32_t)(files.count - 1)) + 1;
            NSString *firstStr = files[0];
            NSString *secondStr = files[index];
            tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:firstStr withString:kTMPREPLACE1];
            tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:secondStr withString:kTMPREPLACE2];
            tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:kTMPREPLACE1 withString:secondStr];
            tmpcontent = [tmpcontent stringByReplacingOccurrencesOfString:kTMPREPLACE2 withString:firstStr];
            [files removeObjectAtIndex:index];
            [files removeObjectAtIndex:0];
        }
        content = [content stringByReplacingOccurrencesOfString:sources withString:tmpcontent];
    }
    return content;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.urls.count;
}

-(CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row{
    return 44;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    DocTableCell *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    if (!cell) {
        cell = [[DocTableCell alloc] init];
        cell.identifier = identifier;
    }
    cell.textf.stringValue = self.urls[row];
    return cell;
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)mixCompileChange:(NSSwitch *)sender {
    if (sender.state == NSControlStateValueOn && !self.rootUrl) {
        [self chooseFiles:^(NSArray<NSURL *> *urls) {
            if ([urls.firstObject.absoluteString hasSuffix:@"xcodeproj"]) {
                self.rootUrl = urls.firstObject.absoluteString;
            } else {
                self.mixCompileView.state = NSControlStateValueOff;
                sender.state = NSControlStateValueOff;
                [self showTip:@"请选择.xcodeproj"];
            }
        } multipleSelection:NO];
    }
}

- (void)prefixChnage:(NSSwitch *)sender {
    if (sender.state == NSControlStateValueOn && !self.rootUrl) {
        [self chooseFiles:^(NSArray<NSURL *> *urls) {
            if ([urls.firstObject.absoluteString hasSuffix:@"xcodeproj"]) {
                self.rootUrl = urls.firstObject.absoluteString;
            } else {
                self.filePrefixView.state = NSControlStateValueOff;
                sender.state = NSControlStateValueOff;
                [self showTip:@"请选择.xcodeproj"];
            }
        } multipleSelection:NO];
    }
}

- (void)classPrefixChange:(NSSwitch *)sender {
    if (sender.state == NSControlStateValueOn && !self.rootUrl) {
        [self chooseFiles:^(NSArray<NSURL *> *urls) {
            if ([urls.firstObject.absoluteString hasSuffix:@"xcodeproj"]) {
                self.rootUrl = urls.firstObject.absoluteString;
            } else {
                self.classPrefixView.state = NSControlStateValueOff;
                sender.state = NSControlStateValueOff;
                [self showTip:@"请选择.xcodeproj"];
            }
        } multipleSelection:NO];
    }
}



- (void)showTip:(NSString *)tip {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.labelText = [NSString stringWithFormat:@"%@\n",tip];
    [hud hide:YES afterDelay:2];
}

- (void)setupView {
    [self.view addSubview:self.addBtn];
    [self.addBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.mas_equalTo(20);
        make.size.mas_equalTo(CGSizeMake(100, 24));
    }];
    
    [self.view addSubview:self.cleanBtn];
    [self.cleanBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.addBtn);
        make.left.equalTo(self.addBtn.mas_right).offset(20);
        make.size.mas_equalTo(CGSizeMake(80, 24));
    }];
    
    NSTableColumn *column1 = [[NSTableColumn alloc] initWithIdentifier:@"columnFrist"];
    column1.title = @"已经选择的目录";
    [column1 setWidth:200];
    [self.tableview addTableColumn:column1];
    
    NSScrollView *tableContainerView = [[NSScrollView alloc] init];
    [tableContainerView setDocumentView:self.tableview];
    [tableContainerView setDrawsBackground:NO];//不画背景（背景默认画成白色）
    [tableContainerView setHasVerticalScroller:YES];//有垂直滚动条
    //[_tableContainer setHasHorizontalScroller:YES];  //有水平滚动条
    tableContainerView.autohidesScrollers = YES;//自动隐藏滚动条（滚动的时候出现）
    [self.view addSubview:tableContainerView];
    [tableContainerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(20);
        make.top.equalTo(self.addBtn.mas_bottom).offset(15);
        make.width.mas_equalTo(400);
        make.bottom.equalTo(self.view).offset(-20);
    }];
    
    
    [self.view addSubview:self.startMixBtn];
    [self.startMixBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(tableContainerView.mas_right).offset(20);
        make.height.mas_equalTo(44);
        make.width.mas_equalTo(400);
        make.bottom.equalTo(self.view).offset(-20);
    }];
    
    [self.view addSubview:self.mixPropView];
    [self.mixPropView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(tableContainerView.mas_right).offset(20);
        make.top.equalTo(self.view).offset(20);
        make.size.mas_equalTo(CGSizeMake(200, 25));
    }];
    
    [self.view addSubview:self.mixMethodView];
    [self.mixMethodView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(tableContainerView.mas_right).offset(20);
        make.top.equalTo(self.mixPropView.mas_bottom).offset(30);
        make.size.mas_equalTo(CGSizeMake(200, 25));
    }];
    
    [self.view addSubview:self.mixImportView];
    [self.mixImportView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(tableContainerView.mas_right).offset(20);
        make.top.equalTo(self.mixMethodView.mas_bottom).offset(30);
        make.size.mas_equalTo(CGSizeMake(200, 25));
    }];
    
    [self.view addSubview:self.deleteNoteView];
    [self.deleteNoteView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(tableContainerView.mas_right).offset(20);
        make.top.equalTo(self.mixImportView.mas_bottom).offset(30);
        make.size.mas_equalTo(CGSizeMake(200, 25));
    }];
    
    [self.view addSubview:self.mixCompileView];
    [self.mixCompileView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(tableContainerView.mas_right).offset(20);
        make.top.equalTo(self.deleteNoteView.mas_bottom).offset(30);
        make.size.mas_equalTo(CGSizeMake(200, 25));
    }];
    
    [self.view addSubview:self.filePrefixView];
    [self.filePrefixView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(tableContainerView.mas_right).offset(20);
        make.top.equalTo(self.mixCompileView.mas_bottom).offset(30);
        make.size.mas_equalTo(CGSizeMake(200, 25));
    }];
    
    [self.view addSubview:self.classPrefixView];
    [self.classPrefixView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(tableContainerView.mas_right).offset(20);
        make.top.equalTo(self.filePrefixView.mas_bottom).offset(30);
        make.size.mas_equalTo(CGSizeMake(200, 25));
    }];
    
    [self.view addSubview:self.insertCodeView];
    [self.insertCodeView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(tableContainerView.mas_right).offset(20);
        make.top.equalTo(self.classPrefixView.mas_bottom).offset(30);
        make.size.mas_equalTo(CGSizeMake(400, 80));
    }];
}

- (NSButton *)addBtn {
    if (!_addBtn) {
        _addBtn = [[NSButton alloc] init];
        //    button.frame = CGRectMake(20, self.view.frame.size.height - 40, 50, 20);
        _addBtn.bezelColor = [NSColor grayColor];
        [_addBtn setTitle:@"选择目录/文件"];
        _addBtn.target = self;
        [_addBtn setAction:@selector(addFile)];
    }
    return _addBtn;
}

- (NSButton *)cleanBtn {
    if (!_cleanBtn) {
        _cleanBtn = [[NSButton alloc] init];
        //    button.frame = CGRectMake(20, self.view.frame.size.height - 40, 50, 20);
        _cleanBtn.bezelColor = [NSColor grayColor];
        [_cleanBtn setTitle:@"重新选择"];
        _cleanBtn.target = self;
        [_cleanBtn setAction:@selector(cleanFile)];
    }
    return _cleanBtn;
}

- (NSButton *)startMixBtn {
    if (!_startMixBtn) {
        _startMixBtn = [[NSButton alloc] init];
        //    button.frame = CGRectMake(20, self.view.frame.size.height - 40, 50, 20);
        _startMixBtn.bezelColor = [NSColor grayColor];
        [_startMixBtn setTitle:@"开始执行"];
        _startMixBtn.target = self;
        _startMixBtn.layer.cornerRadius = 22;
        _startMixBtn.layer.masksToBounds = YES;
        [_startMixBtn setAction:@selector(startMix)];
    }
    return _startMixBtn;
}

- (MFSwitchView *)mixPropView {
    if (!_mixPropView) {
        _mixPropView = [MFSwitchView createViewWithTitle:@"属性" placeholder:nil editEnable:NO switchDefaultState:NSControlStateValueOff];
    }
    return _mixPropView;
}

- (MFSwitchView *)mixMethodView {
    if (!_mixMethodView) {
        _mixMethodView = [MFSwitchView createViewWithTitle:@"方法" placeholder:nil editEnable:NO switchDefaultState:NSControlStateValueOff];
    }
    return _mixMethodView;
}

- (MFSwitchView *)mixImportView {
    if (!_mixImportView) {
        _mixImportView = [MFSwitchView createViewWithTitle:@"Import" placeholder:nil editEnable:NO switchDefaultState:NSControlStateValueOff];
    }
    return _mixImportView;
}

- (MFSwitchView *)deleteNoteView {
    if (!_deleteNoteView) {
        _deleteNoteView = [MFSwitchView createViewWithTitle:@"删除注释" placeholder:nil editEnable:NO switchDefaultState:NSControlStateValueOff];
    }
    return _deleteNoteView;
}

- (MFSwitchView *)mixCompileView {
    if (!_mixCompileView) {
        _mixCompileView = [MFSwitchView createViewWithTitle:@"Sources" placeholder:nil editEnable:NO switchDefaultState:NSControlStateValueOff];
        @weakify(self);
        _mixCompileView.switchAction = ^(NSSwitch *sender) {
            @strongify(self);
            [self mixCompileChange:sender];
        };
    }
    return _mixCompileView;
}

- (MFSwitchView *)filePrefixView {
    if (!_filePrefixView) {
        _filePrefixView = [MFSwitchView createViewWithTitle:@"文件名称" placeholder:@"Prefix" editEnable:YES switchDefaultState:NSControlStateValueOff];
        @weakify(self);
        _filePrefixView.switchAction = ^(NSSwitch *sender) {
            @strongify(self);
            [self prefixChnage:sender];
        };
        
        [[_filePrefixView.textField rac_textSignal] subscribeNext:^(NSString * _Nullable x) {
            @strongify(self);
            self.glFile_prefix = x;
        }];
    }
    return _filePrefixView;
}

- (MFSwitchView *)classPrefixView {
    if (!_classPrefixView) {
        _classPrefixView = [MFSwitchView createViewWithTitle:@"类名" placeholder:@"Prefix" editEnable:YES switchDefaultState:NSControlStateValueOff];
        @weakify(self);
        _classPrefixView.switchAction = ^(NSSwitch *sender) {
            @strongify(self);
            [self classPrefixChange:sender];
        };
        [[_classPrefixView.textField rac_textSignal] subscribeNext:^(NSString * _Nullable x) {
            @strongify(self);
            self.glClass_prefix = x;
        }];
    }
    return _classPrefixView;
}

- (MFSwitchView *)insertCodeView {
    if (!_insertCodeView) {
        _insertCodeView = [MFSwitchView createViewWithTitle:@"插入代码" placeholder:@"code" editEnable:YES switchDefaultState:NSControlStateValueOff];
        @weakify(self);
        [[_insertCodeView.textField rac_textSignal] subscribeNext:^(NSString * _Nullable x) {
            @strongify(self);
            self.insertCode = x;
        }];
    }
    return _insertCodeView;
}

- (NSTableView *)tableview {
    if (!_tableview) {
        _tableview = [[NSTableView alloc] initWithFrame:NSZeroRect];
        _tableview.delegate = self;
        _tableview.dataSource = self;
        _tableview.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
        _tableview.gridColor = [NSColor magentaColor];
    }
    return _tableview;
}

- (NSMutableArray *)urls {
    if (!_urls) {
        _urls = [NSMutableArray array];
    }
    return _urls;
}

- (NSMutableArray *)projectAllFiles {
    if (!_projectAllFiles) {
        _projectAllFiles = [NSMutableArray array];
    }
    return _projectAllFiles;
}

- (NSMutableDictionary<NSString *,NSString *> *)mixedClasses {
    if (!_mixedClasses) {
        _mixedClasses = [NSMutableDictionary dictionary];
    }
    return _mixedClasses;
}

- (NSArray *)filterDirs {
    if (!_filterDirs) {
        _filterDirs = @[
            @".DS_Store",
            @".xcworkspace",
            @"README.md",
            @"Pods",
            @".gitignore",
            @"Podfile",
            @".git",
            @".xcodeproj",
            @"Podfile.lock",
            @".idea",
            @"RealnameAuth",
            @"NSArray-Safe",
            @"ThirdParty",
            @""
        ];
    }
    return _filterDirs;
}

- (NSArray *)filterImps {
    if (!_filterImps) {
        _filterImps = @[
            @"(void)loadView",
            @"(void)load",
            @"viewWillAppear:",
            @"viewWillDisappear",
            @"viewDidAppear:",
            @"viewDidDisappear:",
            @"viewWillLayoutSubviews",
            @"viewDidLayoutSubviews",
            @"(void)didReceiveMemoryWarning",
            @"(void)presentViewController:(UIViewController *)viewControllerToPresent animated: (BOOL)flag completion:",
            @"(void)dismissViewControllerAnimated: (BOOL)flag completion:",
            @"(void)presentModalViewController:(UIViewController *)modalViewController animated:(BOOL)animated",
            @"(void)viewDidLoad",
            @"didReceiveMemoryWarning",
            @"(void)dealloc",
            @"(UIStatusBarStyle)preferredStatusBarStyle",
            @"(void)customviewWillAppear:",
            @"(void)customViewDidLoad",
            @"(instancetype)init",
            @"initWithFrame:",
            @")setUp",
            @"(void)awakeFromNib",
            @"(void)setSelected:(BOOL)selected animated:(BOOL)animated",
            @"(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier",
            @"(void)updateConstraints",
            @")mj_",//mj开头的重写函数
            @")tableView:",
            @")collectionView:",
            @")scrollViewDidScroll:",
            @"ignoreQYVc",
            @")application:",
            
        ];
    }
    return _filterImps;
}

- (NSArray *)inserFilterDirs {
    if (!_inserFilterDirs) {
        NSMutableArray *arr = [NSMutableArray arrayWithObjects:
                               @"HKRouterTool",
                               @"HKLogListViewController",
                               @"QIYU_iOS_SDK_FIX_v5.4",
                               nil];
        [arr addObjectsFromArray:self.filterDirs];
        _inserFilterDirs = arr;
    }
    return _inserFilterDirs;
}

@end
