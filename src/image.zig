const std=@import("std");
///Image buffer abstraction struct.
pub const Image=struct{
//Data
    alloc:std.mem.Allocator,
    ///Width of the output image.
    width:u32,
    ///Height of the output image.
    height:u32,
    ///Runtime image buffer.
    pdata:[]u8,
    ///Runtime Z-Buffer.
    zbuf:[]f32,
//Types
    ///A color is only RGB values, for now.
    const Color=[3]u8;
    const Error=error{OutOfBounds};
//Image Buffer RAII
    ///Initializes a new image buffer.
    ///# Parameters
    ///- width : The width of the image.
    ///- height : The height of the image.
    ///- alloc : Will be used to back the runtime image buffer.
    pub fn init(width:u16,height:u16,alloc:std.mem.Allocator)!Image{
        const width32:u32=@intCast(width);
        const height32:u32=@intCast(height);
        const img=Image{
            .width=width32,
            .height=height32,
            .pdata=try alloc.alloc(u8,width32*height32*3),
            .zbuf=try alloc.alloc(f32,width32*height32),
            .alloc=alloc
        };
        for(0..img.width*img.height)|i|{img.zbuf[i]=-std.math.inf(f32);}
        for(0..(3*img.width*img.height))|i|{img.pdata[i]=0;}
        return img;
    }
    ///Frees runtime image & z-buffer.
    pub fn deinit(self:*Image)void{
        self.alloc.free(self.pdata);
        self.alloc.free(self.zbuf);
    }
    ///Writes the image to a specified output file.
    ///# Parameters
    ///- fname : Path to the output file to be written.
    pub fn write(self:*Image,fname:[]const u8)!void{
        const file=try std.fs.cwd().createFile(fname,.{.read=true});
        defer file.close();
        std.debug.print("Writing to disk...",.{});
        const header:[18]u8=.{
            0,0,2,0,0,0,0,0,0,0,0,0,
            @intCast(self.width&255),
            @intCast((self.width>>8)&255),
            @intCast(self.height&255),
            @intCast((self.height>>8)&255),
            24,
            0b00100000
        };
        try file.writeAll(&header);
        try file.writeAll(self.pdata); 
        std.debug.print("Done!\n",.{});
    }
//Draw Functions
    ///Sets the color of a specific pixel to a specifec color.
    ///# Parameters
    ///- x : X-coordinate of the pixel.
    ///- y : Y-coorfinate of the pixel.
    ///- color : Color to be written.
    pub fn setColor(self:*Image,x:u64,y:u64,color:Color)void{
        var offset=3*(x+y*self.width);
        while(offset+3>=3*self.height*self.width)
            offset-=1;
        for(0..3)|i|{self.pdata.ptr[offset+i]=color[i];}
    }
    ///Draws a line between two specific pixels.
    ///# Parameters
    ///- a0 : X-Coordinate of the first pixel.
    ///- b0 : Y-Coordinate of the first pixel.
    ///- a1 : X-Coordinate of the second pixel.
    ///- b1 : Y-Coordinate of the second pixel.
    ///- color : Color of the line.
    pub fn drawLine(self:*Image,a0:i64,b0:i64,a1:i64,b1:i64,color:Color)void{
        //Order Endpoints
        const transpose:bool=@abs(a1-a0)<@abs(b1-b0);
        var x0=if(transpose)b0 else a0;
        var y0=if(transpose)a0 else b0;
        var x1=if(transpose)b1 else a1;
        var y1=if(transpose)a1 else b1;
        if(x0>x1){
            var tmp:i64=undefined;
            tmp=x0;x0=x1;x1=tmp;
            tmp=y0;y0=y1;y1=tmp;
        }
        //Clamp Endpoints
        x0=std.math.clamp(x0,0,@as(i64,@intCast(self.width-1)));
        x1=std.math.clamp(x1,0,@as(i64,@intCast(self.width-1)));
        y0=std.math.clamp(y0,0,@as(i64,@intCast(self.height)));
        y1=std.math.clamp(y1,0,@as(i64,@intCast(self.height)));
        //Linearly Interpolate A Line
        var y:f32=undefined;
        var t:f32=undefined;
        for(@intCast(x0)..@intCast(x1))|x|{
            t=@as(f32,@floatFromInt(@as(i64,@intCast(x))-x0))/@as(f32,@floatFromInt(x1-x0));
            y=@as(f32,@floatFromInt(y0))*(1.0-t)+@as(f32,@floatFromInt(y1))*t;
            if(transpose)
                {self.setColor(@intFromFloat(y),x,color);}
            else{self.setColor(x,@intFromFloat(y),color);}
        }
    }
    ///Draws a triangle of some specific color between three specific points.
    pub fn drawTriangle(self:*Image,coords:[3][3]f32,color:[3]u8)void{
        //Clamp Vertices
        var verts:[3][3]f32=undefined;
        for(0..3)|i|{
            for(0..2)|j|{
                verts[i][j]=std.math.clamp(
                    coords[i][j],
                    0.0,
                    @as(
                        f32,
                        @floatFromInt(
                            if(j==0)self.width 
                            else self.height
                        )
                    )
                );
            }
            verts[i][2]=coords[i][2];
        }
        //Compute Bounding Box
        var xmin=verts[0][0];
        if(xmin>verts[1][0])xmin=verts[1][0];
        if(xmin>verts[2][0])xmin=verts[2][0];
        var xmax=verts[0][0];
        if(xmax<verts[1][0])xmax=verts[1][0];
        if(xmax<verts[2][0])xmax=verts[2][0];
        var ymin=verts[0][1];
        if(ymin>verts[1][1])ymin=verts[1][1];
        if(ymin>verts[2][1])ymin=verts[2][1];
        var ymax=verts[0][1];
        if(ymax<verts[1][1])ymax=verts[1][1];
        if(ymax<verts[2][1])ymax=verts[2][1];
        //Test Pixels
        var x:f32=xmin;
        while(x<=xmax):(x+=0.5){
            if(x<0.0)unreachable;
            var y:f32=ymin;
            while(y<=ymax):(y+=0.5){
                if(y<0.0)unreachable;
                //Check If Pixel Is In Triangle
                const bc=barycentric(verts,x,y);
                if(bc[0]<0.0 or bc[1]<0.0 or bc[2]<0.0)continue;
                if(bc[0]>1.0 or bc[1]>1.0 or bc[2]>1.0)continue;
                //Check Z-Buffer
                var z:f32=0.0;
                for(0..3)|i|z+=verts[i][2]*bc[i];
                if(self.getZ(@intFromFloat(x),@intFromFloat(y)).?<z){
                    //Update Z-Buffer & Draw Pixel
                    self.setZ(@intFromFloat(x),@intFromFloat(y),z);
                    self.setColor(@intFromFloat(x),@intFromFloat(y),color);
                }
            }
        }
    }
//Edit Functions
    ///Mirrors the image about the horizontal axis.
    pub fn flipV(self:*Image)void{
        var tmp_color:Color=undefined;
        for(0..self.height/2)|y|{
            for(0..self.width)|x|{
                tmp_color=self.getColor(x,y);
                self.setColor(x,y,self.getColor(x,self.height-y));
                self.setColor(x,self.height-y,tmp_color);
            }
        }
    }
//Utility Functions
    ///Returns the color of a specific pixel.
    ///# Parameters
    ///- x : X-coordinate of the pixel.
    ///- y : Y-coordinate of the pixel.
    pub fn getColor(self:*Image,x:usize,y:usize)Color{
        var offset=3*(x+y*self.width);
        while(offset+3>=3*self.height*self.width)
            offset-=1;
        return .{
            self.pdata.ptr[0+offset],
            self.pdata.ptr[1+offset],
            self.pdata.ptr[2+offset]
        };
    }
    ///Returns the current z-value (depth) of a pixel.
    ///# Parameters
    ///- x : X-coordinate of the pixel.
    ///- y : Y-coordinate of the pixel.
    fn getZ(self:*Image,x:usize,y:usize)?f32{
        const offset=x+y*self.width;
        if(offset>=self.height*self.width)return null;
        return self.zbuf.ptr[offset];
    }
    ///Sets the current z-value (depth) of a pixel to a specific value.
    ///# Parameters
    ///- x : X-coordinate of the pixel.
    ///- y : Y-coordinate of the pixel.
    ///- z : Z-value to be written.
    fn setZ(self:*Image,x:usize,y:usize,z:f32)void{
        const offset=x+y*self.width;
        if(offset>=self.height*self.width)return;
        self.zbuf.ptr[offset]=z;
    }
    ///Returns the barycentric coordinates of a specific point, relative to a given triangle.
    ///- verts : Coordinates of each vertex of the triangle.
    ///- x : X-coordinate of the pixel.
    ///- y : Y-coordinate of the pixel.
    fn barycentric(verts:[3][3]f32,x:f32,y:f32)[3]f32{
        const a:[3]f32=.{
            verts[2][0]-verts[0][0],
            verts[1][0]-verts[0][0],
            verts[0][0]-x
        };
        const b:[3]f32=.{
            verts[2][1]-verts[0][1],
            verts[1][1]-verts[0][1],
            verts[0][1]-y
        };
        const c:[3]f32=.{
            a[1]*b[2]-a[2]*b[1],
            a[2]*b[0]-a[0]*b[2],
            a[0]*b[1]-a[1]*b[0]
        };
        if(@abs(c[2])<1)return.{-1.0,-1.0,-1.0};
        return.{
            1.0-(c[0]+c[1])/c[2],
            c[1]/c[2],
            c[0]/c[2]
        };
    }
};
//Tests
///Tests whether or not two given colors are the same.
fn color_eq(a:Image.Color,b:Image.Color)bool{
    for(0..3)|i|if(a[i]!=b[i])return false;
    return true;
}
test"Test `setColor` & `getColor`"{
    var alloc=std.heap.page_allocator;
    var img=Image{
        .width=10,
        .height=10,
        .pdata=alloc.alloc(u8,300) catch unreachable,
        .zbuf=alloc.alloc(f32,100) catch unreachable,
        .alloc=alloc
    };
    defer alloc.free(img.pdata);
    defer alloc.free(img.zbuf);
    const color:Image.Color=[3]u8{255,0,0};
    img.setColor(5,5,color);
    const pixel_color=img.getColor(5,5);
    std.debug.assert(color_eq(pixel_color,color));
}
//test"Test `flip_vertical`"{
//    const alloc=std.heap.page_allocator;
//    var img=Image{
//        .width=10,
//        .height=10,
//        .pdata=try alloc.alloc(u8,300),
//        .zbuf=try alloc.alloc(f32,100),
//        .alloc=alloc
//    };
//    defer alloc.free(img.pdata);
//    defer alloc.free(img.zbuf);
//    for(0..3)|i|img.setColor(i,0,[3]u8{255,0,0});
//    std.debug.assert(color_eq(img.getColor(0,0),[3]u8{255,0,0}));
//    std.debug.assert(color_eq(img.getColor(1,0),[3]u8{255,0,0}));
//    std.debug.assert(color_eq(img.getColor(2,0),[3]u8{255,0,0}));
//    img.flipV();
//    std.debug.assert(color_eq(img.getColor(0,2),[3]u8{255,0,0}));
//    std.debug.assert(color_eq(img.getColor(1,2),[3]u8{255,0,0}));
//    std.debug.assert(color_eq(img.getColor(2,2),[3]u8{255,0,0}));
//}
