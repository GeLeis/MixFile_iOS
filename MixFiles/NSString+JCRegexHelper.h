//
//  NSString+JCRegexHelper.h
//  正则表达式
//
//  Created by abc on 2017/5/10.
//  Copyright © 2017年 JackCat. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>


//.匹配任一字符。p.p匹配pop,pup,pmp,p@p等等。
//\w匹配任意“word-like”字符，包括数字，字母，下划线，不过不能匹配标点符号和其他字符。hello\w会匹配”hello_“,”hello9”和”helloo”,但不匹配”hello!”。
//\d 匹配数字，大部分情况下是[0-9]。\d\d?:\d\d会匹配时间格式的字符串，比如”9：30“和”12：45“。
//\b 匹配额外的字符，例如空格，标点符号。to\b 会匹配”to the moon”和“to!”中得“to”,但是不会匹配“tomorrow”。\b 用在整个单词的匹配方面和方便。
//\s 会匹配空白字符，比如，空格，制表符，换行符。hello\s 会匹配“Well,hello there!”中的 “hello ”。
//^用在一行的开始。记住，这个特殊的^不同于方括号中的^!例如，^Hello 会匹配字符串“Hello there”，而不会去匹配“He said Hello”。
//$ 用在一行的结束，例如，the end$ 会匹配“It was the end” 而不会去匹配 “the end was near”。
//* 匹配 它之前的元素0次或多次。12*3  会匹配 13, 123, 1223, 122223, 和 1222222223。
//+ 匹配 它之前的元素1次或多次. 12+3  会匹配  123, 1223, 122223, 和 1222222223。
//花括号{}包含了匹配的最大和值最小个数。例如，10{1，2}1会匹配“101”和“1001”，而不会匹配“10001”，因为匹配的最小个数为1，最大个数为2。He[LI]{2,}o会匹配“HeLLo”和“HellLLLIo”和任意其他的“hello”添加多个L的变种，所以没有限制，因为，最少的个数是2，最大的个数没有设置。

//小结：
//第一种匹配需要学习NSPredicate的写法，需要查阅苹果相关技术文档；如果只关心第一个匹配的结果，第二种匹配较为简洁；如果需要匹配多个结果，同时匹配多次，第三种方式效率会更高。
//原文地址：http://blog.163.com/nijino_saki/blog/static/80092144201347101658511/

@interface NSString (JCRegexHelper)

#pragma mark - 是否匹配、包含匹配、匹配个数

/**
 是否匹配正则
 */
- (BOOL)matchWithRegex:(NSString*)pattern;

/**
 包含正则内容个数
 */
- (NSInteger)numberOfMatchesWithRegex:(NSString*)pattern;

/**
 是否包含正则内容
 */
- (BOOL)containMathWithRegex:(NSString*)pattern;

#pragma mark - 查找匹配

/**
 找出第一个匹配的内容
 */
- (NSTextCheckingResult *)firstMatchWithRegex:(NSString*)pattern;


/**
 找出所有匹配的内容
 */
- (NSArray<NSTextCheckingResult*>*)matchesWithRegex:(NSString*)pattern;

#pragma mark - 替换、删除

/**
 根据正则和模板进行替换
 */
- (NSString*)replaceWithRegex:(NSString*)pattern withTemplate:(NSString*)withTemplate;


/**
 根据正则和内容进行替换
 */
- (NSString*)replaceWithRegex:(NSString*)pattern withString:(NSString*)withString;

#pragma mark - 公共方法

/**
 根据正则删除内容
 */
- (NSString*)removeWithRegex:(NSString*)pattern;

@end
