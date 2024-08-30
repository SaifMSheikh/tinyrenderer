const Image=@import("image.zig").Image;
const Model=@import("model.zig").Model;
const std=@import("std");
pub fn main()!void{
    var gpa=std.heap.GeneralPurposeAllocator(.{}){};
    const allocator=gpa.allocator();
    defer if(gpa.deinit()==.leak){std.debug.print("GPA detected leak\n",.{});};
    //Load Model Data From Input File
    var arena_allocator=std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    var model=try Model.init("obj/african_head.obj",arena_allocator.allocator());
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
    var img=Image{.height=height,.width=width,.pdata=&data};
    for(0..(3*width*height))|i|{data.ptr[i]=0;}
    //Draw
    std.debug.print("Processing {} vertices...",.{model.verts.items.len});
    for(model.faces.items)|face|{
        for(0..3)|i|{
            const v0=model.verts.items[face[i]-1];
            const v1=model.verts.items[face[(i+1)%3]-1];
            var x0:i64=@intFromFloat((v0[0]+1.0)*width/2.0);
            var y0:i64=@intFromFloat((v0[1]+1.0)*height/2.0);
            var x1:i64=@intFromFloat((v1[0]+1.0)*width/2.0);
            var y1:i64=@intFromFloat((v1[1]+1.0)*height/2.0);
            img.drawLine(&x0,&y0,&x1,&y1,.{255}**3);
        }
    }
    std.debug.print("Done.\n",.{});
    //Write To File
    img.flip_vertical();
    std.debug.print("Saving to disk...",.{});
    try file.writeAll(data);
    std.debug.print("Done!\n",.{});
}
