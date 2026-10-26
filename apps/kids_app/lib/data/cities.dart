/// محافظات مصر + خيار "خارج مصر". الرقم المحفوظ = ترتيب المحافظة في القائمة.
/// (لا نحفظ أي موقع دقيق، فقط رقم المحافظة واسم الحي الذي يكتبه الأهل اختياريًا.)
const citiesAr = <String>[
  'القاهرة', 'الجيزة', 'الإسكندرية', 'القليوبية', 'الدقهلية', 'الشرقية', 'الغربية', 'المنوفية', 'البحيرة',
  'كفر الشيخ', 'دمياط', 'بورسعيد', 'الإسماعيلية', 'السويس', 'شمال سيناء', 'جنوب سيناء', 'الفيوم', 'بني سويف',
  'المنيا', 'أسيوط', 'سوهاج', 'قنا', 'الأقصر', 'أسوان', 'البحر الأحمر', 'الوادي الجديد', 'مطروح', 'خارج مصر',
];

const citiesEn = <String>[
  'Cairo', 'Giza', 'Alexandria', 'Qalyubia', 'Dakahlia', 'Sharqia', 'Gharbia', 'Monufia', 'Beheira',
  'Kafr El Sheikh', 'Damietta', 'Port Said', 'Ismailia', 'Suez', 'North Sinai', 'South Sinai', 'Faiyum', 'Beni Suef',
  'Minya', 'Asyut', 'Sohag', 'Qena', 'Luxor', 'Aswan', 'Red Sea', 'New Valley', 'Matrouh', 'Outside Egypt',
];

String cityName(int i, bool ar) {
  if (i < 0 || i >= citiesAr.length) return '';
  return ar ? citiesAr[i] : citiesEn[i];
}
