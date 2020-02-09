//
//  MFSwitchView.h
//  MixFiles
//
//  Created by gelei on 2020/2/9.
//  Copyright © 2020 gelei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MFSwitchView : NSView
@property (nonatomic, strong) NSTextField *textField;
@property (nonatomic, strong) NSSwitch *switchBtn;
@property (nonatomic, assign) NSControlStateValue state;
@property (nonatomic, copy) void(^switchAction)(NSSwitch *sender);

+ (instancetype)createViewWithTitle:(NSString *)title
                        placeholder:(NSString *)placeholder
                         editEnable:(BOOL)editEnable
                 switchDefaultState:(NSControlStateValue)switchDefaultState;
@end
