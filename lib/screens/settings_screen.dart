import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';
import '../core/cnpj_formatter.dart';
import '../models/session.dart';
import '../state/app_controller.dart';
import '../widgets/section_card.dart';
import '../widgets/company_logo.dart';
import '../widgets/logout_confirmation.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, this.onOpenCompany, super.key});
  final AppController controller;
  final VoidCallback? onOpenCompany;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(color: SteelColors.graphite, border: Border.all(color: const Color(0xFF303A40)), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const _HeaderIcon(),
              const SizedBox(width: 17),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('preferencesTitle'), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -.5)), const SizedBox(height: 5), Text(strings.get('preferencesCaption'), style: const TextStyle(color: Colors.white70))])),
            ]),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle(icon: Icons.palette_outlined, eyebrow: strings.get('appearance'), title: strings.get('systemTheme'), caption: strings.get('themeCaption')),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _ThemeOption(title: strings.get('lightTheme'), caption: strings.get('brightPlaces'), icon: Icons.light_mode_rounded, selected: !controller.darkMode, onTap: () => controller.setDarkMode(false))),
                const SizedBox(width: 12),
                Expanded(child: _ThemeOption(title: strings.get('darkTheme'), caption: strings.get('reduceBrightness'), icon: Icons.dark_mode_rounded, selected: controller.darkMode, onTap: () => controller.setDarkMode(true))),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle(icon: Icons.translate_rounded, eyebrow: strings.get('language'), title: strings.get('interfaceLanguage'), caption: strings.get('languageSaved')),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 3 : 2;
                final names = ['Português', 'English', 'Español', 'Français', 'Deutsch', 'Italiano'];
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: names.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 58),
                  itemBuilder: (_, index) {
                    final selected = controller.language == AppLanguage.values[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => controller.setLanguage(AppLanguage.values[index]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: selected ? SteelColors.industrialAccent.withValues(alpha: .10) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .45), border: Border.all(color: selected ? SteelColors.industrialAccent : Theme.of(context).dividerColor, width: selected ? 1.5 : 1), borderRadius: BorderRadius.circular(9)),
                        child: Row(children: [Icon(selected ? Icons.check_circle_rounded : Icons.language_rounded, color: selected ? SteelColors.industrialAccentDark : SteelColors.muted, size: 20), const SizedBox(width: 9), Expanded(child: Text(names[index], style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w600)))]),
                      ),
                    );
                  },
                );
              }),
            ]),
          ),
          const SizedBox(height: 14),
          FutureBuilder<Company>(
            future: controller.companyApi.getCompany(),
            builder: (context, snapshot) => SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionTitle(icon: Icons.apartment_rounded, eyebrow: strings.get('organization'), title: strings.get('company'), caption: strings.get('companyData')),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
                else if (snapshot.hasError)
                  Text(strings.get('retry'))
                else ...[
                  _CompanySummary(company: snapshot.data!, strings: strings, token: controller.session?.token),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onOpenCompany, icon: const Icon(Icons.manage_accounts_outlined), label: Text(strings.get('manageCompany')))),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: SteelColors.danger.withValues(alpha: .09), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.logout_rounded, color: SteelColors.danger)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.get('endSession'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 3), Text(strings.get('endSessionCaption'), style: const TextStyle(color: SteelColors.muted, fontSize: 12))])),
              OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: SteelColors.danger, side: BorderSide(color: SteelColors.danger.withValues(alpha: .35))), onPressed: () async { if (await confirmLogout(context) && context.mounted) await controller.logout(); }, icon: const Icon(Icons.logout_rounded, size: 18), label: Text(strings.get('logout'))),
            ]),
          ),
        ],
      );
  }
}

class _CompanySummary extends StatelessWidget {
  const _CompanySummary({required this.company, required this.strings, required this.token});
  final Company company;
  final AppStrings strings;
  final String? token;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .42), border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          CompanyLogo(company: company, token: token, size: 56),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(company.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)), const SizedBox(height: 3), Text('CNPJ: ${formatCnpj(company.cnpj)}', style: const TextStyle(color: SteelColors.muted, fontSize: 12))])),
          Builder(builder: (context) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return Chip(
              avatar: const Icon(Icons.circle, size: 9, color: SteelColors.success),
              label: Text(strings.get('activeCompany')),
              backgroundColor: dark ? SteelColors.success.withValues(alpha: .14) : const Color(0xFFEAF7F0),
              side: BorderSide(color: dark ? SteelColors.success.withValues(alpha: .38) : const Color(0xFFAEDBC4)),
              labelStyle: TextStyle(color: dark ? const Color(0xFFBDEBD2) : const Color(0xFF176B45), fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            );
          }),
        ]),
      );
}

class _HeaderIcon extends StatelessWidget { const _HeaderIcon(); @override Widget build(BuildContext context) => Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFF20282D), border: Border.all(color: const Color(0xFF354047)), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.tune_rounded, color: Color(0xFFFFB84D), size: 26)); }
class _SectionTitle extends StatelessWidget { const _SectionTitle({required this.icon, required this.eyebrow, required this.title, required this.caption}); final IconData icon; final String eyebrow,title,caption; @override Widget build(BuildContext context) => Row(children: [Container(width: 48,height:48,decoration:BoxDecoration(color:SteelColors.industrialAccent.withValues(alpha:.09),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:SteelColors.industrialAccentDark)),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(eyebrow,style:const TextStyle(color:SteelColors.industrialAccentDark,fontSize:9,fontWeight:FontWeight.w700,letterSpacing:.75)),const SizedBox(height:3),Text(title,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:2),Text(caption,style:const TextStyle(color:SteelColors.muted,fontSize:12))]))]); }
class _ThemeOption extends StatelessWidget { const _ThemeOption({required this.title,required this.caption,required this.icon,required this.selected,required this.onTap}); final String title,caption; final IconData icon; final bool selected; final VoidCallback onTap; @override Widget build(BuildContext context)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(10),child:AnimatedContainer(duration:const Duration(milliseconds:180),padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:selected?SteelColors.industrialAccent.withValues(alpha:.09):Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha:.42),border:Border.all(color:selected?SteelColors.industrialAccent:Theme.of(context).dividerColor,width:selected?1.6:1),borderRadius:BorderRadius.circular(10)),child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:selected?SteelColors.industrialAccentDark:SteelColors.muted.withValues(alpha:.1),borderRadius:BorderRadius.circular(9)),child:Icon(icon,color:selected?Colors.white:SteelColors.muted)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:2),Text(caption,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:SteelColors.muted,fontSize:11))])),Icon(selected?Icons.check_circle_rounded:Icons.circle_outlined,color:selected?SteelColors.industrialAccentDark:SteelColors.muted,size:20)]))); }
