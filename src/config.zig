const std=@import("std");
///Encapsulates configuration state, taken from command-line arguments.
pub const Config=struct{
    ///Input model file.
    infile:[]const u8="obj/teapot.obj",
    ///Output image file.
    outfile:[]const u8="img.tga",
    ///Output Image width.
    width:u16=1024,
    ///Output Image height.
    height:u16=1024,
    ///Specifies whether or not to draw wireframe.
    f_wire:bool=false,
    ///Screen-space X-offset.
    x_offset:f32=0.0,
    ///Screen-space Y-offset.
    y_offset:f32=0.0,
    ///Input Model scale.
    scale:f32=1.0,
    const Error=error{InvalidArgument,InvalidCharacter,Overflow};
    ///Extracts configuration state from command-line arguments.
    pub fn parseArgs()Config.Error!Config{
        //Extract Command Line Arguments
        const args=std.os.argv;
        std.debug.print("Arguments :",.{});
        if(args.len>0){for(1..args.len)|i|std.debug.print(" {s}",.{args[i]});}
        else{std.debug.print("None\n",.{});}
        std.debug.print("\n",.{});
        //Parse Arguments
        var cfg=Config{};
        for(1..args.len)|idx|{
            const arg=std.mem.span(args[idx]);
            var val:[]const u8="";
            if(idx+1<args.len)val=std.mem.span(args[idx+1]);
            if(std.mem.eql(u8,arg,"--wireframe")){cfg.f_wire=true;}
            else if(std.mem.eql(u8,arg,"--in")){cfg.infile=val;}
            else if(std.mem.eql(u8,arg,"--out")){cfg.outfile=val;}
            else if(std.mem.eql(u8,arg,"--width")){cfg.width=try std.fmt.parseInt(u16,val,10);}
            else if(std.mem.eql(u8,arg,"--height")){cfg.height=try std.fmt.parseInt(u16,val,10);}
            else if(std.mem.eql(u8,arg,"--x-offset")){cfg.x_offset=try std.fmt.parseFloat(f32,val);}
            else if(std.mem.eql(u8,arg,"--y-offset")){cfg.y_offset=try std.fmt.parseFloat(f32,val);}
            else if(std.mem.eql(u8,arg,"--scale")){cfg.scale=try std.fmt.parseFloat(f32,val);}
        }
        return cfg;
    }
};
