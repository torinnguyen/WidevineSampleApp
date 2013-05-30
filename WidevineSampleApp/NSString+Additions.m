//
//  NSString+Additions.m
//  Aurora
//
//  Created by Daud Abas on 24/2/12.
//  Copyright (c) 2012 2359 Media Pte Ltd. All rights reserved.
//

#import <time.h>
#import "NSString+Additions.h"
#import <CommonCrypto/CommonDigest.h>
#import "ISO8601DateFormatter.h"

@implementation NSString (Additions)

- (NSUInteger)wordCount {
  NSScanner *scanner = [NSScanner scannerWithString: self];
  NSCharacterSet *whiteSpace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  
  NSUInteger count = 0;
  while ([scanner scanUpToCharactersFromSet: whiteSpace  intoString: nil])
    count++;
  
  return count;
}

- (BOOL)contains:(NSString*)needle {
  NSRange range = [self rangeOfString:needle options: NSCaseInsensitiveSearch];
  return (range.length == needle.length && range.location != NSNotFound);
}

- (BOOL)startsWith:(NSString*)needle {
  NSRange range = [self rangeOfString:needle options: NSCaseInsensitiveSearch];
  return (range.length == needle.length && range.location == 0);
}

- (BOOL)endsWith:(NSString*)needle {
  NSRange range = [self rangeOfString:needle options: NSCaseInsensitiveSearch];
  return (range.length == needle.length && range.location == (self.length-range.length-1));
}

- (NSString *)URLEncodedString
{
  __autoreleasing NSString *encodedString;
  
  NSString *originalString = (NSString *)self;    
  encodedString = (__bridge_transfer NSString * )
  CFURLCreateStringByAddingPercentEscapes(NULL,
                                          (__bridge CFStringRef)originalString,
                                          (CFStringRef)@"$-_.+!*'(),&+/:;=?@#",
                                          NULL,
                                          kCFStringEncodingUTF8);
  encodedString = [encodedString stringByReplacingOccurrencesOfString:@"%25" withString:@"\%"];   //revert double escape
  return encodedString;
}

- (NSString *)URLEncodeEverything
{
    __autoreleasing NSString *encodedString;
    
    NSString *originalString = (NSString *)self;    
    encodedString = (__bridge_transfer NSString * )
    CFURLCreateStringByAddingPercentEscapes(NULL,
                                            (__bridge CFStringRef)originalString,
                                            NULL,
                                            (CFStringRef)@"$-_.+!*'(),&+/:;=?@#",
                                            kCFStringEncodingUTF8);
    encodedString = [encodedString stringByReplacingOccurrencesOfString:@"%25" withString:@"\%"];   //revert double escape
    return encodedString;
}


- (NSString *)sha1 {
  const char *cStr = [self UTF8String];
  unsigned char result[CC_SHA1_DIGEST_LENGTH];
  CC_SHA1(cStr, strlen(cStr), result);
  NSString *s = [NSString  stringWithFormat:
                 @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                 result[0], result[1], result[2], result[3], result[4],
                 result[5], result[6], result[7],
                 result[8], result[9], result[10], result[11], result[12],
                 result[13], result[14], result[15],
                 result[16], result[17], result[18], result[19]
                 ];
  
  return s;
}

- (NSString *)md5 {
  const char *cStr = [self UTF8String];
  unsigned char result[CC_MD5_DIGEST_LENGTH];
  CC_MD5(cStr, strlen(cStr), result);
  NSString *s = [NSString  stringWithFormat:
                 @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                 result[0], result[1], result[2], result[3], result[4],
                 result[5], result[6], result[7],
                 result[8], result[9], result[10], result[11], result[12],
                 result[13], result[14], result[15]
                 ];
  
  return s;
}

- (NSDate*)dateFromString
{
  static ISO8601DateFormatter *dateFormatter = nil;
  if (dateFormatter == nil)
    dateFormatter = [[ISO8601DateFormatter alloc] init];

  NSDate *theDate = [dateFormatter dateFromString:self];
  return theDate;
}

- (NSString *)camelCaseToUnderscore
{
  NSMutableString *output = [NSMutableString string];
  NSCharacterSet *uppercase = [NSCharacterSet uppercaseLetterCharacterSet];
  BOOL previousCharacterWasUppercase = FALSE;
  BOOL currentCharacterIsUppercase = FALSE;
  unichar currentChar = 0;
  unichar previousChar = 0;
  for (NSInteger idx = 0; idx < [self length]; idx += 1) {
    previousChar = currentChar;
    currentChar = [self characterAtIndex:idx];
    previousCharacterWasUppercase = currentCharacterIsUppercase;
    currentCharacterIsUppercase = [uppercase characterIsMember:currentChar];
    
    if (!previousCharacterWasUppercase && currentCharacterIsUppercase && idx > 0) {
      // insert an _ between the characters
      [output appendString:@"_"];
    } else if (previousCharacterWasUppercase && !currentCharacterIsUppercase) {
      // insert an _ before the previous character
      // insert an _ before the last character in the string
      if ([output length] > 1) {
        unichar charTwoBack = [output characterAtIndex:[output length]-2];
        if (charTwoBack != '_') {
          [output insertString:@"_" atIndex:[output length]-1];
        }
      }
    }
    // Append the current character lowercase
    [output appendString:[[NSString stringWithCharacters:&currentChar length:1] lowercaseString]];
  }
  return output;
}

- (NSString *)underscoreToCamelCase
{
  NSMutableString *output = [NSMutableString string];
  BOOL makeNextCharacterUpperCase = NO;
  for (NSInteger idx = 0; idx < [self length]; idx += 1) {
    unichar c = [self characterAtIndex:idx];
    if (c == '_') {
      makeNextCharacterUpperCase = YES;
    } else if (makeNextCharacterUpperCase) {
      [output appendString:[[NSString stringWithCharacters:&c length:1] uppercaseString]];
      makeNextCharacterUpperCase = NO;
    } else {
      [output appendFormat:@"%C", c];
    }
  }
  return output;
}

@end
