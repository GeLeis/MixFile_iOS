//
//  DocTableCell.m
//  MixFiles
//
//  Created by gelei on 2019/12/12.
//  Copyright © 2019 gelei. All rights reserved.
//

#import "DocTableCell.h"
#import <Masonry/Masonry.h>

@implementation DocTableCell

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        _textf = [[NSTextField alloc] init];
        _textf.textColor = [NSColor whiteColor];
        [self addSubview:_textf];
        [_textf mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self);
        }];
    }
    return self;
}

@end
