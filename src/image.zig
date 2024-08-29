const std=@import("std");
pub const Image=struct{
//Data
    width:u64,
    height:u64,
    pdata:*[]u8,
//Types
    const Color=[3]u8;
//Draw Functions
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
            else self.setColor(x,@intFromFloat(y),color);
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
};
