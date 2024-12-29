const Config=@import("config.zig").Config;
const Image=@import("image.zig").Image;
const Model=@import("model.zig").Model;
const std=@import("std");
pub fn main()!void{
    //Extract Command Line Arguments
    const cfg=try Config.parseArgs();
    //Initialize Allocator
    var gpa=std.heap.GeneralPurposeAllocator(.{}){};
    const allocator=gpa.allocator();
    defer if(gpa.deinit()==.leak){std.debug.print("GPA detected leak\n",.{});};
    //Load Model Data From Input File
    var model=try Model.init(cfg.infile,allocator);
    model.scale(cfg.scale);
    defer model.deinit();
    //Create Empty Image
    var img=try Image.init(cfg.width,cfg.height,allocator);
    defer img.deinit();
    //Draw
    std.debug.print("Processing {} vertices...",.{model.verts.len});
    const light_dir:[3]f32=.{0,0,-1};
    var scrn_coords:[3][3]f32=undefined;
    var wrld_coords:[3][3]f32=undefined;
    for(0..model.faces.len)|f|{
        const face=model.faces[f];
        //Fetch Vertices
        for(0..3)|i|{
            wrld_coords[i]=model.verts[face[i]-1];
            scrn_coords[i][0]=(wrld_coords[i][0]+1.0)*@as(f32,@floatFromInt(cfg.width))/2.0+cfg.x_offset;
            scrn_coords[i][1]=(wrld_coords[i][1]+1.0)*@as(f32,@floatFromInt(cfg.height))/2.0+cfg.y_offset;
            scrn_coords[i][2]=wrld_coords[i][2];
        }
        //Compute Shade
        var a:[3]f32=undefined;
        for(0..3)|i|a[i]=wrld_coords[2][i]-wrld_coords[0][i];
        var b:[3]f32=undefined;
        for(0..3)|i|b[i]=wrld_coords[1][i]-wrld_coords[0][i];
        var n:[3]f32=.{
            a[1]*b[2]-a[2]*b[1],
            a[2]*b[0]-a[0]*b[2],
            a[0]*b[1]-a[1]*b[0]
        };
        const mag_n=std.math.sqrt(n[0]*n[0]+n[1]*n[1]+n[2]*n[2]);
        for(0..3)|i|n[i]/=mag_n;
        var intensity:f32=0;
        for(0..3)|i|intensity+=n[i]*light_dir[i];
        //Draw Face
        if(intensity<0.0)continue;
        img.drawTriangle(
            scrn_coords,
            .{@as(u8,@intFromFloat(255.0*intensity))}**3
        );
    }
    //Wireframe For Debugging
    if(cfg.f_wire){
        for(model.faces)|face|{
            for(0..3)|i|{
                const v0=model.verts[face[i]-1];
                const v1=model.verts[face[(i+1)%3]-1];
                const x0:i64=@intFromFloat((v0[0]+1.0)*@as(f32,@floatFromInt(cfg.width))/2.0+cfg.x_offset);
                const y0:i64=@intFromFloat((v0[1]+1.0)*@as(f32,@floatFromInt(cfg.height))/2.0+cfg.y_offset);
                const x1:i64=@intFromFloat((v1[0]+1.0)*@as(f32,@floatFromInt(cfg.width))/2.0+cfg.x_offset);
                const y1:i64=@intFromFloat((v1[1]+1.0)*@as(f32,@floatFromInt(cfg.height))/2.0+cfg.y_offset);
                img.drawLine(x0,y0,x1,y1,.{50,50,125});
            }
        }
    }
    //Write To File
    img.flipV();
    try img.write(cfg.outfile);
}
