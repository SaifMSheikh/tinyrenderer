const std=@import("std");
pub const Image=struct{
//Data
    width:u64,
    height:u64,
    pdata:*[]u8,
//Types
    const Color=[3]u8;
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
    pub fn drawTriangle(self:*Image,a0:f32,b0:f32,a1:f32,b1:f32,a2:f32,b2:f32,color:[3]u8)void{
        //Clamp Vertices
        const x0:f32=std.math.clamp(a0,0.0,@as(f32,@floatFromInt(self.width)));
        const x1:f32=std.math.clamp(a1,0.0,@as(f32,@floatFromInt(self.width)));
        const x2:f32=std.math.clamp(a2,0.0,@as(f32,@floatFromInt(self.width)));
        const y0:f32=std.math.clamp(b0,0.0,@as(f32,@floatFromInt(self.height)));
        const y1:f32=std.math.clamp(b1,0.0,@as(f32,@floatFromInt(self.height)));
        const y2:f32=std.math.clamp(b2,0.0,@as(f32,@floatFromInt(self.height)));
        if(y0==y1 and y0==y2)return;
        //Compute Bounding Box
        var xmin=x0;
        if(xmin>x1)xmin=x1;
        if(xmin>x2)xmin=x2;
        var xmax=x0;
        if(xmax<x1)xmax=x1;
        if(xmax<x2)xmax=x2;
        var ymin=y0;
        if(ymin>y1)ymin=y1;
        if(ymin>y2)ymin=y2;
        var ymax=y0;
        if(ymax<y1)ymax=y1;
        if(ymax<y2)ymax=y2;
        //Test Pixels
        var x:f32=xmin;
        while(x<=xmax):(x+=0.5){
            var y:f32=ymin;
            while(y<=ymax):(y+=0.5){
                const bc=barycentric(x0,y0,x1,y1,x2,y2,x,y);
                if(bc[0]<0.0 or bc[1]<0.0 or bc[2]<0.0){continue;}
                else if(bc[0]>1.0 or bc[1]>1.0 or bc[2]>1.0){continue;}
                else{self.setColor(@intFromFloat(x),@intFromFloat(y),color);}
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
    pub fn getColor(self:*Image,x:u64,y:u64)Color{
        var offset=3*(x+y*self.width);
        while(offset+3>=3*self.height*self.width)
            offset-=1;
        return .{
            self.pdata.ptr[0+offset],
            self.pdata.ptr[1+offset],
            self.pdata.ptr[2+offset]
        };
    }
    fn barycentric(x0:f32,y0:f32,x1:f32,y1:f32,x2:f32,y2:f32,px:f32,py:f32)[3]f32{
        const a:[3]f32=.{
            x2-x0,
            x1-x0,
            x0-px
        };
        const b:[3]f32=.{
            y2-y0,
            y1-y0,
            y0-py
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
