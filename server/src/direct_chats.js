import {createHash} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
const fail=(status,message)=>Object.assign(new Error(message),{status,code:'DIRECT_CHAT_ERROR'});
export const directChatId=(a,b)=>createHash('sha256').update(JSON.stringify([a,b].sort())).digest('hex');
export function registerDirectChats(app,{db,protectedRoute,notifications,messageLimit}) {
  const refFor=value=>{
    if(typeof value!=='string'|| !/^[a-f0-9]{64}$/.test(value)) throw fail(400,'Mã cuộc trò chuyện không hợp lệ.');
    return db.collection('directChats').doc(value);
  };
  const authorize=(row,uid)=>{
    if(!row.exists) throw fail(404,'Không tìm thấy cuộc trò chuyện.');
    if(!row.data().participantIds?.includes(uid)) throw fail(403,'Bạn không thuộc cuộc trò chuyện này.');
    return row.data();
  };
  app.post('/api/direct-chats',protectedRoute,async(req,res)=>{
    const username=typeof req.body?.username==='string'?req.body.username.trim().toLowerCase():'';
    if(!/^[a-z0-9_]{3,30}$/.test(username)) throw fail(400,'Username cần 3–30 ký tự: a-z, 0-9, _.');
    const target=(await db.collection('usernames').doc(username).get()).data()?.uid;
    if(!target) throw fail(404,'Không tìm thấy người dùng với username này.');
    if(target===req.uid) throw fail(400,'Vui lòng chọn người khác để trò chuyện.');
    const ref=db.collection('directChats').doc(directChatId(req.uid,target));
    await db.runTransaction(async tx=>{
      const [room,profile]=await Promise.all([tx.get(ref),tx.get(db.collection('users').doc(target))]);
      if(!profile.exists) throw fail(404,'Tài khoản này không còn tồn tại.');
      if(!room.exists) tx.create(ref,{participantIds:[req.uid,target].sort(),names:{[req.uid]:req.user.displayName||req.user.username,[target]:profile.data().displayName||profile.data().username||username},createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    });
    res.status(201).json({id:ref.id});
  });
  app.get('/api/direct-chats',protectedRoute,async(req,res)=>{
    const rows=await db.collection('directChats').where('participantIds','array-contains',req.uid).get();
    const rooms=rows.docs.map(d=>{
      const data=d.data(),other=data.participantIds.find(id=>id!==req.uid);
      return {id:d.id,name:data.names?.[other]||'Thành viên',lastMessage:data.lastMessage?{...data.lastMessage,createdAt:data.lastMessage.createdAt?.toDate().toISOString()||null}:null,updatedAt:data.updatedAt?.toDate().toISOString()||null};
    }).sort((a,b)=>(b.updatedAt||'').localeCompare(a.updatedAt||''));
    res.json({rooms});
  });
  app.get('/api/direct-chats/:id/messages',protectedRoute,async(req,res)=>{
    const ref=refFor(req.params.id);authorize(await ref.get(),req.uid);
    let query=ref.collection('messages').orderBy('createdAt','desc').limit(100);
    if(req.query.before){
      if(typeof req.query.before!=='string'||req.query.before.includes('/')||req.query.before.length>1500) throw fail(400,'Mốc tin nhắn không hợp lệ.');
      const before=await ref.collection('messages').doc(req.query.before).get();
      if(!before.exists) throw fail(404,'Không tìm thấy mốc tin nhắn.');
      query=query.startAfter(before);
    }
    const rows=await query.get();
    res.json({messages:rows.docs.reverse().map(d=>({id:d.id,...d.data(),createdAt:d.data().createdAt?.toDate().toISOString()||null})),hasMore:rows.size===100});
  });
  app.post('/api/direct-chats/:id/messages',protectedRoute,messageLimit,async(req,res)=>{
    const content=req.body?.content;
    if(typeof content!=='string'||!content.trim()||content.trim().length>2000) throw fail(400,'Tin nhắn cần từ 1 đến 2000 ký tự.');
    const ref=refFor(req.params.id),message=ref.collection('messages').doc();
    const senderName=req.user.displayName||req.user.username||'Thành viên';
    const jobs=await db.runTransaction(async tx=>{
      const data=authorize(await tx.get(ref),req.uid);
      const body={senderId:req.uid,senderName,content:content.trim(),createdAt:FieldValue.serverTimestamp()};
      tx.create(message,body);
      tx.update(ref,{lastMessage:{id:message.id,...body},updatedAt:FieldValue.serverTimestamp(),[`names.${req.uid}`]:senderName});
      return notifications.stage(tx,data.participantIds.filter(uid=>uid!==req.uid),{type:'chat',title:`${senderName} đã gửi tin nhắn riêng`,body:Array.from(content.trim()).slice(0,160).join(''),conversationId:ref.id,targetId:message.id,actorId:req.uid,actorName:senderName});
    });
    await notifications.deliver(jobs);res.status(201).json({id:message.id});
  });
  app.post('/api/direct-chats/:id/read',protectedRoute,async(req,res)=>{
    const ref=refFor(req.params.id);authorize(await ref.get(),req.uid);
    const id=req.body?.messageId;
    if(typeof id!=='string'||!id||id.includes('/')||id.length>1500) throw fail(400,'Mã tin nhắn không hợp lệ.');
    const message=await ref.collection('messages').doc(id).get();
    if(!message.exists) throw fail(404,'Không tìm thấy tin nhắn.');
    const cutoff=message.data().createdAt;
    if(cutoff?.toMillis?.()==null) throw fail(409,'Tin nhắn đang được lưu.');
    const inbox=await db.collection('users').doc(req.uid).collection('notifications').get();
    const rows=inbox.docs.filter(d=>{const n=d.data();return n.type==='chat'&&n.conversationId===ref.id&&n.chatRead!==true&&n.createdAt && (typeof n.createdAt.seconds==='number' && typeof cutoff.seconds==='number' ? n.createdAt.seconds<cutoff.seconds || (n.createdAt.seconds===cutoff.seconds && n.createdAt.nanoseconds<=cutoff.nanoseconds) : n.createdAt.toMillis?.()<=cutoff.toMillis());});
    for(let i=0;i<rows.length;i+=400){const batch=db.batch();rows.slice(i,i+400).forEach(d=>batch.update(d.ref,{chatRead:true}));await batch.commit();}
    res.json({message:'Đã đọc tin nhắn.'});
  });
}
