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

@interface MFSwitchView ()
@property (nonatomic, strong) NSTextField *titleField;
@end

@implementation MFSwitchView

+ (instancetype)createViewWithTitle:(NSString *)title placeholder:(NSString *)placeholder editEnable:(BOOL)editEnable switchDefaultState:(NSControlStateValue)switchDefaultState {
    MFSwitchView *view = [[MFSwitchView alloc] initWithFrame:NSZeroRect];
    view.titleField.stringValue = title?:@"";
    view.textField.hidden = !editEnable;
    if (editEnable) {
        view.textField.placeholderString = placeholder;
    }
    view.switchBtn.state = switchDefaultState;
    return view;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _titleField = [[NSTextField alloc] init];
        _titleField.textColor = NSColor.whiteColor;
        _titleField.editable = NO;
        [self addSubview:_titleField];
        [_titleField mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.offset(0);
            make.top.equalTo(self);
            make.size.mas_equalTo(CGSizeMake(kLabelW, 20));
        }];
        
        _switchBtn = [[NSSwitch alloc] init];
        [self addSubview:_switchBtn];
        [_switchBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.titleField.mas_right).offset(20);
            make.centerY.equalTo(self.titleField);
        }];
        _switchBtn.target = self;
        [_switchBtn setAction:@selector(switchValueChange:)];
        
        _textField = [[NSTextField alloc] init];
        _textField.textColor = NSColor.whiteColor;
        _textField.maximumNumberOfLines = 0;
        _textField.stringValue = @"";
        [self addSubview:_textField];
        [_textField mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.switchBtn.mas_right).offset(20);
            make.top.bottom.right.equalTo(self);
        }];
        _textField.action = @selector(textFieldAction:);
        _textField.target = self;
    }
    return self;
}

- (void)switchValueChange:(NSSwitch *)sender {
    self.state = sender.state;
    if (self.switchAction) {
        self.switchAction(sender);
    }
}

- (void)textFieldAction:(NSTextField *)sender {
    [sender.window makeFirstResponder:self];
}

@end
