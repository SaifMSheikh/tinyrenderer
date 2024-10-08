const Image=@import("image.zig").Image;
const Model=@import("model.zig").Model;
const std=@import("std");
pub fn main()!void{
    var gpa=std.heap.GeneralPurposeAllocator(.{}){};
    const allocator=gpa.allocator();
    defer if(gpa.deinit()==.leak){std.debug.print("GPA detected leak\n",.{});};
    //Load Model Data From Input File
    var model=try Model.init("obj/african_head.obj",allocator);
    defer model.deinit();
    //Open Output File
    const file=try std.fs.cwd().createFile("img.tga",.{.read=true});
    defer file.close();
    //Write Header
    const width:u32=1000;
    const height:u32=1000;
    const header:[18]u8=.{
        0,0,2,0,0,0,0,0,0,0,0,0,
        width&255,
        (width>>8)&255,
        height&255,
        (height>>8)&255,
        24,
        0b00100000
    };
    try file.writeAll(&header);
    //Empty Image
    var data=try allocator.alloc(u8,width*height*3);
    defer allocator.free(data);
    var zbuf=try allocator.alloc(f32,width*height);
    defer allocator.free(zbuf);
    for(0..width*height)|i|{zbuf[i]=-std.math.inf(f32);}
    var img=Image{.height=height,.width=width,.zbuf=&zbuf,.pdata=&data};
    for(0..(3*width*height))|i|{data.ptr[i]=0;}
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
            scrn_coords[i][0]=(wrld_coords[i][0]+1.0)*width/2.0;
            scrn_coords[i][1]=(wrld_coords[i][1]+1.0)*height/2.0;
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
//    for(model.faces.items)|face|{
//        for(0..3)|i|{
//            const v0=model.verts.items[face[i]-1];
//            const v1=model.verts.items[face[(i+1)%3]-1];
//            const x0:i64=@intFromFloat((v0[0]+1.0)*width/2.0);
//            const y0:i64=@intFromFloat((v0[1]+1.0)*height/2.0);
//            const x1:i64=@intFromFloat((v1[0]+1.0)*width/2.0);
//            const y1:i64=@intFromFloat((v1[1]+1.0)*height/2.0);
//            img.drawLine(x0,y0,x1,y1,.{50,50,125});
//        }
//    }
    std.debug.print("Done.\n",.{});
    //Write To File
    img.flip_vertical();
    std.debug.print("Saving to disk...",.{});
    try file.writeAll(data);
    std.debug.print("Done!\n",.{});
}
