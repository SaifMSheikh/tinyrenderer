const std=@import("std");
pub const Image=struct{
//Data
    width:u64,
    height:u64,
    pdata:*[]u8,
    zbuf:*[]f32,
//Types
    const Color=[3]u8;
    const Error=error{
        OutOfBounds,
    };
//Draw Functions
    pub fn setColor(self:*Image,x:u64,y:u64,color:Color)void{
        var offset=3*(x+y*self.width);
        while(offset+3>=3*self.height*self.width)
            offset-=1;
        for(0..3)|i|{self.pdata.ptr[offset+i]=color[i];}
    }
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
    pub fn flip_vertical(self:*Image)void{
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
    fn getZ(self:*Image,x:usize,y:usize)?f32{
        const offset=x+y*self.width;
        if(offset>=self.height*self.width)return null;
        return self.zbuf.ptr[offset];
    }
    fn setZ(self:*Image,x:usize,y:usize,z:f32)void{
        const offset=x+y*self.width;
        if(offset>=self.height*self.width)return;
        self.zbuf.ptr[offset]=z;
    }
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
