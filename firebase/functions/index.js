// دالة سحابية يستدعيها تطبيق المدير لإرسال إشعار لكل الأطفال المشتركين في موضوع "kids".
// تحتاج خطة Blaze في Firebase.
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

exports.sendKidsNotification = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'سجّل الدخول أولًا');
  const admin = await getFirestore().doc(`admins/${uid}`).get();
  if (!admin.exists) throw new HttpsError('permission-denied', 'هذه العملية للمدير فقط');

  const title = String((request.data && request.data.title) || '').trim().slice(0, 80);
  const body = String((request.data && request.data.body) || '').trim().slice(0, 240);
  if (!title) throw new HttpsError('invalid-argument', 'العنوان مطلوب');

  const id = await getMessaging().send({
    topic: 'kids',
    notification: { title, body },
    android: { priority: 'high', notification: { channelId: 'kids_default' } }
  });
  await getFirestore().collection('notificationsLog').add({ title, body, by: uid, at: new Date(), messageId: id });
  return { ok: true, id };
});
