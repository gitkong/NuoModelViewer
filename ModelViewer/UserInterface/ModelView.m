//
//  ModelView.m
//  ModelViewer
//
//  Created by middleware on 8/26/16.
//  Copyright © 2016 middleware. All rights reserved.
//

#import "ModelView.h"
#import "ModelOperationPanel.h"
#import "LightOperationPanel.h"

#import "ModelViewerRenderer.h"
#import "NotationRenderer.h"

#import "NuoLua.h"
#import "NuoMeshOptions.h"



@interface ModelView() <ModelOptionUpdate>

@end




@implementation ModelView
{
    NuoLua* _lua;
    ModelRenderer* _modelRender;
    NotationRenderer* _notationRender;
    NSArray<NuoRenderPass*>* _renders;
    
    ModelOperationPanel* _modelPanel;
    LightOperationPanel* _lightPanel;
    
    BOOL _trackingLighting;
    
    NSString* _documentName;
}



- (NuoLua*)lua
{
    if (!_lua)
        _lua = [[NuoLua alloc] init];
    
    return _lua;
}



- (NSRect)operationPanelLocation
{
    NSRect viewRect = [self frame];
    NSSize panelSize = NSMakeSize(225, 285);
    NSSize panelMargin = NSMakeSize(15, 25);
    NSPoint panelOrigin = NSMakePoint(viewRect.size.width - panelMargin.width - panelSize.width,
                                      viewRect.size.height - panelMargin.height - panelSize.height);
    
    NSRect panelRect;
    panelRect.origin = panelOrigin;
    panelRect.size = panelSize;
    
    return panelRect;
}



- (void)addModelOperationPanel
{
    NSRect panelRect = [self operationPanelLocation];
    
    _modelPanel = [ModelOperationPanel new];
    _modelPanel.frame = panelRect;
    _modelPanel.layer.opacity = 0.8f;
    _modelPanel.layer.backgroundColor = [NSColor colorWithWhite:1.0 alpha:1.0].CGColor;
    
    [_modelPanel addCheckbox];
    [_modelPanel setOptionUpdateDelegate:self];
    
    [self addSubview:_modelPanel];
}


- (void)addLightOperationPanel
{
    CGRect area = [self lightPanelRect];
    
    _lightPanel = [[LightOperationPanel alloc] initWithFrame:area];
    [self addSubview:_lightPanel];
    [_lightPanel setHidden:YES];
    [_lightPanel setOptionUpdateDelegate:self];
}


- (void)modelUpdate:(ModelOperationPanel *)panel
{
    NuoMeshOption* options = panel.meshOptions;
    
    [_modelRender setModelOptions:options];
    [self render];
}


- (void)modelOptionUpdate:(ModelOperationPanel *)panel
{
    [_modelRender setCullEnabled:[panel cullEnabled]];
    [_modelRender setFieldOfView:[panel fieldOfViewRadian]];
    [_modelRender setAmbientDensity:[panel ambientDensity]];
    [self setupPipelineSettings];
    [self render];
}



- (void)lightOptionUpdate:(LightOperationPanel*)panel;
{
    _notationRender.density = [panel lightDensity];
    [self render];
}



- (void)viewResizing
{
    [super viewResizing];
    
    NSRect viewRect = [self frame];
    NSSize popupSize = NSMakeSize(200, 25);
    NSSize popupMargin = NSMakeSize(10, 10);
    NSPoint popupOrigin = NSMakePoint(viewRect.size.width - popupMargin.width - popupSize.width,
                                      viewRect.size.height - popupMargin.height - popupSize.height);
    
    NSRect popupRect;
    popupRect.origin = popupOrigin;
    popupRect.size = popupSize;
    
    if (!_modelPanel)
    {
        [self addModelOperationPanel];
    }
    
    [_modelPanel setFrame:[self operationPanelLocation]];
    
    if (!_lightPanel)
    {
        [self addLightOperationPanel];
    }
    
    [_lightPanel setFrame:[self lightPanelRect]];
}



- (void)commonInit
{
    [super commonInit];
    
    _modelRender = [[ModelRenderer alloc] initWithDevice:self.metalLayer.device];
    _notationRender = [[NotationRenderer alloc] initWithDevice:self.metalLayer.device];
    _notationRender.notationWidthCap = [self operationPanelLocation].size.width + 50;
    
    [self setupPipelineSettings];
    
    [self registerForDraggedTypes:@[@"public.data"]];
}


- (NSRect)lightPanelRect
{
    const CGFloat margin = 8;
    
    CGRect area = [_notationRender notationArea];
    NSRect result = area;
    CGFloat width = area.size.width;
    width = width * 0.8;
    result.origin.y = area.origin.y - margin;
    result.origin.x += (area.size.width - width) / 2.0;
    result.size.width = width;
    result.size.height = 18;
    
    return result;
}


- (void)setupPipelineSettings
{
    if (_modelPanel.showLightSettings)
    {
        _renders = [[NSArray alloc] initWithObjects:_modelRender, _notationRender, nil];
        
        NuoRenderPassTarget* modelRenderTarget = [NuoRenderPassTarget new];
        modelRenderTarget.device = self.metalLayer.device;
        modelRenderTarget.sampleCount = kSampleCount;
        modelRenderTarget.clearColor = MTLClearColorMake(0.95, 0.95, 0.95, 1);
        modelRenderTarget.manageTargetTexture = YES;
        
        [_modelRender setRenderTarget:modelRenderTarget];
        
        NuoRenderPassTarget* notationRenderTarget = [NuoRenderPassTarget new];
        notationRenderTarget.device = self.metalLayer.device;
        notationRenderTarget.sampleCount = 1;
        notationRenderTarget.clearColor = MTLClearColorMake(0.95, 0.95, 0.95, 1);
        notationRenderTarget.manageTargetTexture = NO;
        
        [_notationRender setRenderTarget:notationRenderTarget];
    }
    else
    {
        _renders = [[NSArray alloc] initWithObjects:_modelRender, nil];
        
        NuoRenderPassTarget* modelRenderTarget = [NuoRenderPassTarget new];
        modelRenderTarget.device = self.metalLayer.device;
        modelRenderTarget.sampleCount = kSampleCount;
        modelRenderTarget.clearColor = MTLClearColorMake(0.95, 0.95, 0.95, 1);
        modelRenderTarget.manageTargetTexture = NO;
        
        [_modelRender setRenderTarget:modelRenderTarget];
    }

    [_lightPanel setHidden:!_modelPanel.showLightSettings];
    
    [self setRenderPasses:_renders];
    [self viewResizing];
}


- (void)mouseDown:(NSEvent *)event
{
    if (_modelPanel.showLightSettings)
    {
        NSPoint location = event.locationInWindow;
        location = [self convertPoint:location fromView:nil];
        
        CGRect lightSettingArea = _notationRender.notationArea;
        _trackingLighting = CGRectContainsPoint(lightSettingArea, location);
        
        if (_trackingLighting)
        {
            [_notationRender selectCurrentLightVector:location];
            [_lightPanel setLightDensity:_notationRender.density];
        }
    }
    else
    {
        _trackingLighting = NO;
    }
}


- (void)mouseUp:(NSEvent *)event
{
    _trackingLighting = NO;
    [self render];
}


- (void)mouseDragged:(NSEvent *)theEvent
{
    float deltaX = -0.01 * M_PI * theEvent.deltaY;
    float deltaY = -0.01 * M_PI * theEvent.deltaX;
    
    if (_trackingLighting)
    {
        _notationRender.rotateX += deltaX;
        _notationRender.rotateY += deltaY;
    }
    else
    {
        _modelRender.rotationXDelta = deltaX;
        _modelRender.rotationYDelta = deltaY;
    }
    
    [self render];
}


- (void)magnifyWithEvent:(NSEvent *)event
{
    _modelRender.zoom += 10 * event.magnification;
    [self render];
}



- (void)scrollWheel:(NSEvent *)event
{
    _modelRender.transX -= event.deltaX;
    _modelRender.transY += event.deltaY;
    [self render];
}


- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    NSPasteboard* paste = [sender draggingPasteboard];
    NSArray *draggedFilePaths = [paste propertyListForType:NSFilenamesPboardType];
    
    if (draggedFilePaths.count > 0)
    {
        NSString* path = draggedFilePaths[0];
        if ([path hasSuffix:@".obj"])
        {
            return NSDragOperationGeneric;
        }
        else
        {
            NSFileManager* manager = [NSFileManager defaultManager];
            BOOL isDir = false;
            
            [manager fileExistsAtPath:path isDirectory:&isDir];
            if (isDir)
            {
                NSString* name = [path lastPathComponent];
                name = [name stringByAppendingString:@".obj"];
                
                NSString* filePath = [path stringByAppendingPathComponent:name];
                return [manager fileExistsAtPath:filePath];
            }
        }
    }
    
    return NSDragOperationNone;
}


- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
    return YES;
}


- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard* paste = [sender draggingPasteboard];
    NSArray *draggedFilePaths = [paste propertyListForType:NSFilenamesPboardType];
    NSString* path = draggedFilePaths[0];
    
    NSFileManager* manager = [NSFileManager defaultManager];
    BOOL isDir = false;
    
    [manager fileExistsAtPath:path isDirectory:&isDir];
    if (isDir)
    {
        NSString* name = [path lastPathComponent];
        name = [name stringByAppendingString:@".obj"];
        path = [path stringByAppendingPathComponent:name];
    }
    
    [self loadMesh:path];
    [self render];
    return YES;
}



- (void)render
{
    _modelRender.lights = _notationRender.lightSources;
    [super render];
}



- (void)loadMesh:(NSString*)path
{
    [_modelRender loadMesh:path];
    
    NSString* documentName = [path lastPathComponent];
    _documentName = [documentName stringByDeletingPathExtension];
    NSString* title = [[NSString alloc] initWithFormat:@"ModelView - %@", documentName];
    [self.window setTitle:title];
}



- (void)loadScene:(NSString*)path
{
    NuoLua* lua = [self lua];
    [lua loadFile:path];
    
    CGSize drawableSize;
    [lua getField:@"canvas" fromTable:-1];
    drawableSize.width = [lua getFieldAsNumber:@"width" fromTable:-1];
    drawableSize.height = [lua getFieldAsNumber:@"height" fromTable:-1];
    [lua removeField];
    
    NSWindow* window = self.window;
    [window setContentSize:drawableSize];
    
    [_modelRender importScene:lua];
    [_notationRender importScene:lua];
    
    [_modelPanel setFieldOfViewRadian:_modelRender.fieldOfView];
    [_modelPanel setAmbientDensity:_modelRender.ambientDensity];
    [_modelPanel updateControls];
}



- (IBAction)openFile:(id)sender
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    openPanel.allowedFileTypes = @[@"obj", @"scn"];
    
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result)
            {
                if (result == NSFileHandlingPanelOKButton)
                {
                    NSString* path = openPanel.URL.path;
                    NSString* ext = path.pathExtension;
                    
                    if ([ext isEqualToString:@"obj"])
                        [self loadMesh:path];
                    
                    if ([ext isEqualToString:@"scn"])
                        [self loadScene:path];
                    
                    [self render];
                }
            }];
}



- (IBAction)saveScene:(id)sender
{
    NSString* defaultName = _documentName;
    if (!defaultName)
        defaultName = @" ";
    
    NSSavePanel* savePanel = [NSSavePanel savePanel];
    [savePanel setNameFieldStringValue:defaultName];
    [savePanel setCanSelectHiddenExtension:YES];
    [savePanel setAllowedFileTypes:@[@"scn"]];
    
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result)
             {
                 if (result == NSFileHandlingPanelOKButton)
                 {
                     NSString* path = savePanel.URL.path;
                     NSString* result = [_modelRender exportSceneAsString:[self.window contentView].frame.size];
                     const char* pathStr = path.UTF8String;
                     
                     FILE* file = fopen(pathStr, "w");
                     fwrite(result.UTF8String, sizeof(char), result.length, file);
                     fclose(file);
                 }
             }];
        }



@end
