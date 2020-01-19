//
//  NSString+JCRegexHelper.m
//  正则表达式
//
//  Created by abc on 2017/5/10.
//  Copyright © 2017年 JackCat. All rights reserved.
//

#import "NSString+JCRegexHelper.h"

@implementation NSString (JCRegexHelper)

/**
 是否匹配正则
 */
- (BOOL)matchWithRegex:(NSString*)pattern{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",pattern];
    return [predicate evaluateWithObject:self];
}

/**
 包含正则内容个数
 */
- (NSInteger)numberOfMatchesWithRegex:(NSString*)pattern{
    NSRegularExpression *regex = [self regexWithPattern:pattern];
    
    return [regex numberOfMatchesInString:self options:NSMatchingReportProgress range:NSMakeRange(0, self.length)];
}

/**
 是否包含正则内容
 */
- (BOOL)containMathWithRegex:(NSString*)pattern{
    return [self numberOfMatchesWithRegex:pattern] > 0;
}

/**
 找出第一个匹配的内容
 */
- (NSTextCheckingResult *)firstMatchWithRegex:(NSString*)pattern{
    
    NSRegularExpression *regex = [self regexWithPattern:pattern];
    
    return [regex firstMatchInString:self options:NSMatchingReportProgress range:NSMakeRange(0, self.length)];
}

/**
 找出所有匹配的内容
 */
- (NSArray<NSTextCheckingResult*>*)matchesWithRegex:(NSString*)pattern{
    NSRegularExpression *regex = [self regexWithPattern:pattern];
    return  [regex matchesInString:self options:NSMatchingReportProgress range:NSMakeRange(0, self.length)];
}

/**
 根据正则和模板进行替换
 */
- (NSString*)replaceWithRegex:(NSString*)pattern withTemplate:(NSString*)withTemplate{
    NSRegularExpression *regex = [self regexWithPattern:pattern];
    return [regex stringByReplacingMatchesInString:self options:NSMatchingReportProgress range:NSMakeRange(0, self.length) withTemplate:withTemplate];
}

/**
 根据正则和内容进行替换
 */
- (NSString*)replaceWithRegex:(NSString*)pattern withString:(NSString*)withString{
    return [self replaceWithRegex:pattern withTemplate:withString];
}

/**
 根据正则删除内容
 */
- (NSString*)removeWithRegex:(NSString*)pattern{
    return [self replaceWithRegex:pattern withTemplate:@""];
}

- (NSRegularExpression*)regexWithPattern:(NSString*)pattern{
    NSError *error = NULL;
    return [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
}

@end
