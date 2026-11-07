/* Infraestrutura cenográfica: sem IDs de máquina, telemetria ou execução de comandos. */
(function(root){'use strict';const T=root.THREE;
function build({columns=1,rows=1,count=1}={}){
 const group=new T.Group();group.name='steel-industrial-context';group.userData.visualOnly=true;
 const geometries=[new T.BoxGeometry(1,1,1),new T.CylinderGeometry(1,1,1,20)],materials={steel:new T.MeshStandardMaterial({color:0x8e9ca4,metalness:.67,roughness:.52}),frame:new T.MeshStandardMaterial({color:0x344752,metalness:.48,roughness:.66}),amber:new T.MeshStandardMaterial({color:0xb68a34,metalness:.22,roughness:.7}),wood:new T.MeshStandardMaterial({color:0x897050,roughness:.88}),dark:new T.MeshStandardMaterial({color:0x182630,roughness:.82})};
 const w=Math.max(12,Math.min(48,columns*8+4)),depth=Math.max(11,Math.min(40,rows*7+4));
 function mesh(geometry,material,x,y,z,sx,sy,sz){const n=new T.Mesh(geometry,materials[material]);n.position.set(x,y,z);n.scale.set(sx,sy,sz);n.castShadow=true;n.receiveShadow=true;group.add(n);return n;}
 const box=(x,y,z,a,b,c,mat='steel')=>mesh(geometries[0],mat,x,y,z,a,b,c);
 function cylinder(x,y,z,r,h,mat='steel',axis='y'){const n=mesh(geometries[1],mat,x,y,z,r,h,r);if(axis==='z')n.rotation.x=Math.PI/2;if(axis==='x')n.rotation.z=Math.PI/2;return n;}
 function pallet(x,z){for(const dx of [-.42,0,.42])box(x+dx,.12,z,.12,.2,1.05,'wood');for(let i=0;i<5;i++)box(x,.25,z-.45+i*.225,1.1,.07,.14,'wood');}
 function rack(x,z){for(const dx of [-1.8,1.8])for(const dz of [-.62,.62])box(x+dx,1.8,z+dz,.08,3.6,.08,'frame');for(const y of [.25,1.4,2.55]){box(x,y,z,3.8,.08,1.4,'steel');for(const dz of [-.68,.68])box(x,y+.04,z+dz,3.9,.14,.08,'amber');for(const dx of [-1.18,0,1.18]){box(x+dx,y+.34,z,.92,.58,1.05,'wood');box(x+dx,y+.66,z,.94,.025,1.07,'frame');}}}
 function rollers(x,z,length){for(const dx of [-length/2+.3,length/2-.3])for(const dz of [-.6,.6])box(x+dx,.48,z+dz,.09,.94,.09,'frame');for(const dz of [-.72,.72])box(x,1.02,z+dz,length,.17,.1,'steel');
 const n=Math.max(8,Math.round(length/.22)),inst=new T.InstancedMesh(geometries[1],materials.steel,n),m=new T.Object3D();for(let i=0;i<n;i++){m.position.set(x-length/2+.14+i*(length-.28)/(n-1),1.02,z);m.rotation.x=Math.PI/2;m.scale.set(.065,1.3,.065);m.updateMatrix();inst.setMatrixAt(i,m.matrix);}inst.castShadow=true;inst.receiveShadow=true;group.add(inst);
 }
 // Bancadas de roletes passivos, mesas e racks compõem o galpão; não são ativos cadastrados.
 rack(-w/2+2.3,-depth/2+1.4);rack(w/2-2.3,-depth/2+1.4);
 rollers(0,-3.1,Math.min(8,w-3));rollers(-w/2+1.45,1.1,3.2);
 for(const x of [-3.8,3.8]){cylinder(x,.52,2.3,.28,.95,'frame');cylinder(x,1.04,2.3,1.05,.12,'steel');cylinder(x,.16,2.3,.58,.14,'dark');}
 for(const [x,z]of [[-3.8,-1],[4.3,.1],[w/2-1.6,3.8]]){pallet(x,z);box(x,.61,z,.87,.65,.83,'frame');for(const dz of [-.44,.44])box(x,.95,z+dz,.92,.035,.035,'steel');}
 // Tela de proteção representativa, modelada como linhas 3D e postes.
 const vertices=[],back=-depth/2+.65;for(let x=-w/2+.5;x<=w/2-.5;x+=1.6){box(x,.88,back,.055,1.76,.055,'amber');}
 for(const y of [.2,1.1,1.75])box(0,y,back,w-1,.035,.035,'amber');
 for(let x=-w/2+.6;x<w/2-.6;x+=.26){vertices.push(x,.25,back,x,1.7,back);}for(let y=.25;y<1.7;y+=.26){vertices.push(-w/2+.6,y,back,w/2-.6,y,back);}
 const lines=new T.BufferGeometry();lines.setAttribute('position',new T.Float32BufferAttribute(vertices,3));geometries.push(lines);const wire=new T.LineBasicMaterial({color:0x8d9d9d,transparent:true,opacity:.38});group.add(new T.LineSegments(lines,wire));
 group.userData.layout={columns,rows,count};
 return {group,dispose(){group.traverse(node=>{if(node.isInstancedMesh&&typeof node.dispose==='function')node.dispose();});group.clear();geometries.forEach(g=>g.dispose());Object.values(materials).forEach(m=>m.dispose());wire.dispose();}};
}
root.SteelFactoryContext={build};
})(typeof globalThis!=='undefined'?globalThis:window);
