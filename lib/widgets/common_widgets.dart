import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Общий виджет для кнопок фильтров
class FilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isAccent;

  const FilterButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isAccent ? const Color(0xFFCCFF00) : const Color(0xFF333333),
        ),
        backgroundColor: const Color(0xFF111111),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.unbounded(
          color: isAccent ? const Color(0xFFCCFF00) : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Общий виджет для AppBar с единым стилем
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final double? elevation;
  final bool showSearchButton;
  final VoidCallback? onSearchTap;

  const CommonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backgroundColor,
    this.elevation,
    this.showSearchButton = false,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> finalActions = [];
    
    if (showSearchButton) {
      finalActions.add(
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: onSearchTap,
        ),
      );
    }
    
    if (actions != null) {
      finalActions.addAll(actions!);
    }
    
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.black,
      elevation: elevation ?? 0,
      title: Text(
        title,
        style: GoogleFonts.unbounded(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
      actions: finalActions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Общий виджет для баннера добавления (студии/образование)
class AddItemBanner extends StatelessWidget {
  final String title;
  final String description;
  final String emailSubject;

  const AddItemBanner({
    super.key,
    required this.title,
    required this.description,
    required this.emailSubject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCCFF00).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FontAwesomeIcons.circlePlus, color: const Color(0xFFCCFF00), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.unbounded(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.manrope(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              try {
                await launchUrl(
                  Uri.parse('mailto:apppliehelp@gmail.com?subject=$emailSubject'),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {}
            },
            child: Text(
              "apppliehelp@gmail.com",
              style: GoogleFonts.manrope(
                color: const Color(0xFFCCFF00),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Общий виджет для обработки ошибок изображений
class ErrorImagePlaceholder extends StatelessWidget {
  final IconData icon;
  final double height;

  const ErrorImagePlaceholder({
    super.key,
    this.icon = FontAwesomeIcons.image,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Icon(icon, color: Colors.grey[800], size: 40),
      ),
    );
  }
}

/// Общий виджет для пустого состояния
class EmptyState extends StatelessWidget {
  final String message;

  const EmptyState({
    super.key,
    this.message = "Ничего не найдено",
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: GoogleFonts.manrope(color: Colors.grey),
      ),
    );
  }
}

/// Общий виджет для кнопки "САЙТ"
class SiteButton extends StatelessWidget {
  final String url;
  final String label;

  const SiteButton({
    super.key,
    required this.url,
    this.label = "САЙТ",
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: url.isNotEmpty
          ? () async {
              try {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } catch (_) {}
            }
          : null,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF333333)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.unbounded(color: Colors.white, fontSize: 11),
      ),
    );
  }
}
