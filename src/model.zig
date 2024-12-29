const std=@import("std");
pub const Model=struct{
//Data
    allocator:std.mem.Allocator,
    verts:[]Vertex,
    faces:[]Face,
//Types
    const Vertex=[3]f32;
    const Face=[3]u32;
//Methods
    pub fn init(filename:[]const u8,allocator:std.mem.Allocator)!Model{
    //Open Input File
        std.debug.print("Loading Model : \"{s}\"\n",.{filename});
        const file=try std.fs.cwd().openFile(filename,.{.mode=.read_only});
        defer file.close();
        const _metadata=try file.metadata();
        const file_len=_metadata.size();
    //Extract Lines From .OBJ File
        //Map File Contents To Memory
        const pdata=try std.posix.mmap(
            null,
            file_len,
            std.posix.PROT.READ,
            .{.TYPE=.SHARED},
            file.handle,
            0
        );
        defer std.posix.munmap(pdata);
        //Set Up Temporary ArrayLists For Each Data Attribute
        var vert_lines=std.ArrayList(usize).init(allocator);
        defer vert_lines.deinit();
        var face_lines=std.ArrayList(usize).init(allocator);
        defer face_lines.deinit();
        var iter:usize=0;
        while(iter<file_len-1):(iter+=1){
            //For Each Line
            if(iter!=0){
                if(pdata[iter]!='\n')continue;
                iter+=1;
            }
            //Store Line In Appropriate ArrayList
            switch(pdata[iter]){
                'v'=>{
                    switch(pdata[iter+1]){
                        ' '=>{try vert_lines.append(iter);},
                        else=>{}
                    }
                },
                'f'=>{try face_lines.append(iter);},
                else=>{}
            }
        }
    //Parse Lines For Object Data
        //Allocator Space For Object Data
        var model=Model{
            .allocator=allocator,
            .verts=try allocator.alloc(Vertex,vert_lines.items.len),
            .faces=try allocator.alloc(Face,face_lines.items.len),
        };
        errdefer model.deinit();
        //Parse Face Data
        for(0..face_lines.items.len)|i|{
            //Fetch & Format Line
            const line_start=face_lines.items[i];
            var line_end=line_start;
            while(line_end<file_len and pdata[line_end]!='\n'){line_end+=1;}
            var line=pdata[line_start..line_end];
            line=line[2..];//Remove Identifier 'f '
            //For Each Parameter (Space-Separated)
            for(0..3)|j|{
                var line_iter:usize=0;
                while(line_iter<line.len and line[line_iter]!=' '){line_iter+=1;}
                const param=line[0..line_iter];
                //Get Vertex Index (First Section Before '/')
                var param_iter:usize=0;
                while(param_iter<param.len and param[param_iter]!='/'){param_iter+=1;}
                model.faces[i][j]=try std.fmt.parseInt(u32,param[0..param_iter],10);
                //Truncate Line
                if(line_iter!=line.len)line=line[line_iter+1..];
            }
        }
        //Parse Vertex Data
        for(0..vert_lines.items.len)|i|{
            //Fetch & Format Line
            const line_start=vert_lines.items[i];
            var line_end=line_start;
            while(line_end<file_len and pdata[line_end]!='\n'){line_end+=1;}
            var line=pdata[line_start..line_end];
            line=line[2..];//Remove Identifier 'v '
            //For Each Parameter (Space-Separated)
            for(0..3)|j|{
                var line_iter:usize=0;
                while(line_iter<line.len and line[line_iter]!=' '){line_iter+=1;}
                //Parse Attribute
                model.verts[i][j]=try std.fmt.parseFloat(f32,line[0..line_iter]);
                //Truncate Line
                if(line_iter!=line.len)line=line[line_iter+1..];
            }
        }
        //Pre-Transform To Fit
        var max_vert:Vertex=Vertex{0.0,0.0,0.0};
        for(model.verts)|vert|{
            if(magnitude(vert)>magnitude(max_vert))
                max_vert=vert;
        }
        const max_mag=magnitude(max_vert);
        if(max_mag>0.9)model.scale(1/(max_mag*1.25));
    //Done
        return model;
    }
    pub fn deinit(self:*Model)void{
        self.allocator.free(self.verts);
        self.allocator.free(self.faces);
    }
//Transform Functions
    pub fn scale(self:*Model,factor:f32)void{
        for(0..self.verts.len)|i|{
            for(0..3)|j|{
                self.verts[i][j]*=factor;
            }
        }
    }
//Utility Functions
    pub fn magnitude(vert:Vertex)f32{
        var out:f32=1;
        for(0..3)|i|out*=std.math.pow(f32,vert[i],2);
        return std.math.sqrt(out);
    }
};
//Tests
test "test model init with valid file"{
    const alloc=std.heap.page_allocator;
    var model=try Model.init("obj/teapot.obj",alloc);
    std.debug.assert(model.verts.len>0);
    std.debug.assert(model.faces.len>0);
    model.deinit();
}
test "test model init with invalid file" {
    _=Model.init("obj/non_existent.obj",std.heap.page_allocator) catch return;
    unreachable;
}

