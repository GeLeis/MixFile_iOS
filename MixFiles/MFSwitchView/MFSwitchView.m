//
//  MFSwitchView.m
//  MixFiles
//
//  Created by gelei on 2020/2/9.
//  Copyright © 2020 gelei. All rights reserved.
//

#import "MFSwitchView.h"
#import <Masonry/Masonry.h>
#import <ReactiveObjC/ReactiveObjC.h>
#define kLabelW 60

@implementation MFSwitchView

+ (instancetype)createViewWithTitle:(NSString *)title placeholder:(NSString *)placeholder editEnable:(BOOL)editEnable switchDefaultState:(NSControlStateValue)switchDefaultState {
    MFSwitchView *view = [[MFSwitchView alloc] initWithFrame:NSZeroRect];
    view.textField.stringValue = title?:@"";
    view.textField.placeholderString = placeholder;
    view.textField.editable = editEnable;
    view.switchBtn.state = switchDefaultState;
    return view;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _textField = [[NSTextField alloc] init];
        _textField.textColor = NSColor.whiteColor;
        [self addSubview:_textField];
        [_textField mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.offset(0);
            make.centerY.equalTo(self);
            make.size.mas_equalTo(CGSizeMake(kLabelW, 20));
        }];
        
        _switchBtn = [[NSSwitch alloc] init];
        [self addSubview:_switchBtn];
        [_switchBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.textField.mas_right).offset(20);
            make.centerY.equalTo(self.textField);
        }];
        _switchBtn.target = self;
        [_switchBtn setAction:@selector(switchValueChange:)];
    }
    return self;
}

- (void)switchValueChange:(NSSwitch *)sender {
    self.state = sender.state;
    if (self.switchAction) {
        self.switchAction(sender);
    }
}

@end
