import 'package:flutter/material.dart' hide Text;
import 'package:flutter/widgets.dart' as w show Text;
import 'store.dart';

/// اللغات: ar (العربية) / fr (Français) / en (English)
class I18n {
  static String lang = 'ar';
  static final ValueNotifier<String> notifier = ValueNotifier('ar');

  static bool get rtl => lang == 'ar';

  static void init() {
    lang = Store.lang;
    notifier.value = lang;
  }

  static Future<void> set(String l) async {
    await Store.setLang(l);
    lang = l;
    notifier.value = l;
  }
}

/// المفتاح هو النص العربي. العربية تعيده كما هو، والفرنسية/الإنجليزية من القاموس.
String tr(String s) {
  if (I18n.lang == 'ar') return s;
  final v = _d[s];
  if (v == null) return s;
  return I18n.lang == 'fr' ? v[0] : v[1];
}

/// بديل لـ Text يترجم النص تلقائياً حسب اللغة الحالية
class Text extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  const Text(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context); // إعادة البناء عند تغيير اللغة
    return w.Text(
      tr(data),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      textDirection: textDirection,
    );
  }
}

// [فرنسي, إنجليزي]
const Map<String, List<String>> _d = {
  'تسجيل الدخول': ["Connexion", "Sign in"],
  'سجّل الدخول بحساب الاشتراك': ["Connectez-vous avec votre abonnement", "Sign in with your subscription"],
  'اسم الحساب (اختياري)': ["Nom du profil (facultatif)", "Profile name (optional)"],
  'رابط السيرفر أو رابط M3U': ["URL du serveur ou lien M3U", "Server URL or M3U link"],
  'اسم المستخدم': ["Nom d'utilisateur", "Username"],
  'كلمة المرور': ["Mot de passe", "Password"],
  'املأ رابط السيرفر واسم المستخدم وكلمة المرور': ["Renseignez l'URL, l'utilisateur et le mot de passe", "Enter the server URL, username and password"],
  'خطأ من السيرفر': ["Erreur du serveur", "Server error"],
  'بيانات الدخول غير صحيحة': ["Identifiants incorrects", "Invalid credentials"],
  'الاشتراك غير فعّال': ["Abonnement inactif", "Subscription inactive"],
  'غير محدود': ["Illimité", "Unlimited"],
  'متابعة المشاهدة': ["Reprendre la lecture", "Continue watching"],
  'الإعدادات': ["Paramètres", "Settings"],
  'البث المباشر': ["TV en direct", "Live TV"],
  'الأفلام': ["Films", "Movies"],
  'المسلسلات': ["Séries", "Series"],
  'ينتهي': ["Expire", "Expires"],
  'تبديل الحساب': ["Changer de profil", "Switch profile"],
  'بحث...': ["Rechercher...", "Search..."],
  '⭐ المفضلة': ["⭐ Favoris", "⭐ Favorites"],
  'تعذر تحميل المحتوى': ["Impossible de charger le contenu", "Couldn't load content"],
  'لا يوجد محتوى': ["Aucun contenu", "No content"],
  'اضغط مطولاً على أي عنصر لإضافته للمفضلة': ["Appui long sur un élément pour l'ajouter aux favoris", "Long-press any item to add it to favorites"],
  'أُضيف إلى المفضلة': ["Ajouté aux favoris", "Added to favorites"],
  'أُزيل من المفضلة': ["Retiré des favoris", "Removed from favorites"],
  'لا يوجد وصف': ["Aucune description", "No description"],
  'متابعة من': ["Reprendre à", "Resume from"],
  'تشغيل': ["Lecture", "Play"],
  'الممثلون': ["Acteurs", "Cast"],
  'المخرج': ["Réalisateur", "Director"],
  'تعذر تحميل الحلقات': ["Impossible de charger les épisodes", "Couldn't load episodes"],
  'الموسم': ["Saison", "Season"],
  'الحلقة': ["Épisode", "Episode"],
  'متابعة': ["Reprendre", "Resume"],
  'تعذر تشغيل الفيديو': ["Lecture impossible", "Couldn't play video"],
  'إعادة المحاولة': ["Réessayer", "Retry"],
  'ابحث عن قناة...': ["Rechercher une chaîne...", "Search channels..."],
  'يعرض الآن': ["En cours", "Now playing"],
  'اختر قناة للتشغيل': ["Choisissez une chaîne", "Pick a channel to play"],
  'تعذر تشغيل القناة': ["Chaîne indisponible", "Couldn't play channel"],
  'إعادة المحاولة...': ["Nouvelle tentative...", "Retrying..."],
  'لا توجد قنوات': ["Aucune chaîne", "No channels"],
  'التالي': ["Ensuite", "Next"],
  'اللغة': ["Langue", "Language"],
  'الحسابات': ["Profils", "Accounts"],
  'إضافة حساب': ["Ajouter un profil", "Add profile"],
  'التشغيل': ["Lecture", "Playback"],
  'صيغة البث المباشر': ["Format du direct", "Live stream format"],
  'جرّب m3u8 إذا كان ts لا يعمل مع سيرفرك': ["Essayez m3u8 si ts ne marche pas avec votre serveur", "Try m3u8 if ts doesn't work with your server"],
  'الحماية': ["Sécurité", "Security"],
  'تعيين رمز سري': ["Définir un code PIN", "Set PIN"],
  'تغيير الرمز السري': ["Changer le code PIN", "Change PIN"],
  'يحمي التصنيفات المخصصة للكبار': ["Protège les catégories pour adultes", "Protects adult categories"],
  'حذف الرمز السري': ["Supprimer le code PIN", "Remove PIN"],
  'البيانات': ["Données", "Data"],
  'مسح سجل المشاهدة': ["Effacer l'historique", "Clear watch history"],
  'مسح المفضلة': ["Effacer les favoris", "Clear favorites"],
  'تم مسح السجل': ["Historique effacé", "History cleared"],
  'تم مسح المفضلة': ["Favoris effacés", "Favorites cleared"],
  'رمز سري جديد (4 أرقام)': ["Nouveau code PIN (4 chiffres)", "New PIN (4 digits)"],
  'إلغاء': ["Annuler", "Cancel"],
  'حفظ': ["Enregistrer", "Save"],
  'يجب أن يتكون الرمز من 4 أرقام': ["Le code doit contenir 4 chiffres", "PIN must be 4 digits"],
  'تم حفظ الرمز السري': ["Code PIN enregistré", "PIN saved"],
  'تم حذف الرمز السري': ["Code PIN supprimé", "PIN removed"],
  'أدخل الرمز السري': ["Saisissez le code PIN", "Enter PIN"],
  'تأكيد': ["Confirmer", "Confirm"],
  'الرمز غير صحيح': ["Code incorrect", "Incorrect PIN"],
  'من يشاهد؟': ["Qui regarde ?", "Who's watching?"],
  'إدارة الحسابات': ["Gérer les profils", "Manage profiles"],
  'تم': ["Terminé", "Done"],
  'حذف الحساب': ["Supprimer le profil", "Delete profile"],
  'هل تريد حذف هذا الحساب؟': ["Voulez-vous supprimer ce profil ?", "Delete this profile?"],
  'حذف': ["Supprimer", "Delete"],
};
