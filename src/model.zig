const std=@import("std");

pub const Model=struct{
//Data
    verts:std.ArrayList(Vertex),
    faces:std.ArrayList(Face),
//Types
    const Vertex=[3]f32;
    const Face=[3]u32;
//Methods
    pub fn init(filename:[]const u8,allocator:std.mem.Allocator)!Model{
        //Open Input File
        std.debug.print("Loading Model : \"{s}\"\n",.{filename});
        const file=try std.fs.cwd().openFile(filename,.{.mode=.read_only});
        defer file.close();
        //Parse Relevant Object Data
        var model=Model{
            .verts=std.ArrayList(Vertex).init(allocator),
            .faces=std.ArrayList(Face).init(allocator)
        };
        var buffer:[40*1024]u8=undefined;
        var reader=file.reader();
        var min_vert_x:Vertex=.{0}**3;
        var min_vert_y:Vertex=.{0}**3;
        var max_vert:Vertex=.{0}**3;
        while(true){
            const line=try reader.readUntilDelimiterOrEof(&buffer,'\n');
            if(line==null)break;
            if(line.?.len==0)continue;
            switch(line.?[0]){
                'v'=>{
                    if(line.?[1]!=' ')continue;
                    var iter=std.mem.split(u8,line.?[2..]," ");
                    outer:while(true){
                        var vert:Vertex=undefined;
                        for(0..3)|i|{
                            const param=iter.next();
                            if(param==null)break:outer;
                            vert[i]=try std.fmt.parseFloat(f32,param.?);
                        }
                        if(magnitude(vert)>magnitude(max_vert))
                            max_vert=vert;
                        if(vert[0]<min_vert_x[0])
                            min_vert_x=vert;
                        if(vert[1]<min_vert_y[0])
                            min_vert_y=vert;
                        try model.verts.append(vert);
                    }
                },
                'f'=>{
                    var vert_buf:Face=undefined;
                    var verts=std.mem.split(u8,line.?[2..]," ");
                    for(0..3)|i|{
                        const vert=verts.next().?;
                        var vert_data=std.mem.split(u8,vert,"/");
                        const vert_index=vert_data.next();
                        vert_buf[i]=try std.fmt.parseInt(u32,vert_index.?,10);
                    }
                    try model.faces.append(vert_buf);
                },
                else=>{}
            }
        }
        //Transforms
        if(magnitude(max_vert)>0.9){
            const factor=1/(magnitude(max_vert)*1.25);
            model.scale(factor);
        }
        //Return 
        return model;
    }
    pub fn deinit(self:*Model)void{
            self.verts.deinit();
            self.faces.deinit();
    }
//Transform Functions
    pub fn scale(self:*Model,factor:f32)void{
        for(0..self.verts.items.len)|i|{
            for(0..3)|j|{
                self.verts.items[i][j]*=factor;
            }
        }
    }
//Utility Functions
    fn magnitude(vert:Vertex)f32{
        var out:f32=1;
        for(0..3)|i|out*=std.math.pow(f32,vert[i],2);
        return std.math.sqrt(out);
    }
};
