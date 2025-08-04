import 'package:flutter/material.dart';
import '../utils/app_settings.dart';
import 'package:easy_localization/easy_localization.dart';

class ColorPickerDialog extends StatelessWidget {
  final Color currentColor;
  final Function(Color) onColorSelected;

  const ColorPickerDialog({
    super.key,
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
                   child: Container(
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.surface,
                 borderRadius: BorderRadius.circular(20),
                 boxShadow: [
                   BoxShadow(
                     color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                     blurRadius: 20,
                     offset: const Offset(0, 10),
                   ),
                 ],
               ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.color_lens,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                                       Text(
                         'accent_color'.tr(),
                         style: TextStyle(
                           fontSize: 20,
                           fontWeight: FontWeight.bold,
                           color: Theme.of(context).colorScheme.onSurface,
                         ),
                       ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Current color display
                               Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: Theme.of(context).colorScheme.surfaceVariant,
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Theme.of(context).colorScheme.outline),
                     ),
              child: Row(
                children: [
                                           Container(
                           width: 40,
                           height: 40,
                           decoration: BoxDecoration(
                             color: currentColor,
                             shape: BoxShape.circle,
                             border: Border.all(color: Theme.of(context).colorScheme.outline),
                           ),
                         ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                                                                Text(
                                 'current_color'.tr(),
                                 style: TextStyle(
                                   fontSize: 12,
                                   color: Theme.of(context).colorScheme.onSurfaceVariant,
                                 ),
                               ),
                               Text(
                                 AppSettings.getColorName(currentColor),
                                 style: TextStyle(
                                   fontSize: 16,
                                   fontWeight: FontWeight.w600,
                                   color: Theme.of(context).colorScheme.onSurface,
                                 ),
                               ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Color grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: AppSettings.availableAccentColors.length,
              itemBuilder: (context, index) {
                final color = AppSettings.availableAccentColors[index];
                final isSelected = color.value == currentColor.value;
                
                return GestureDetector(
                  onTap: () {
                    onColorSelected(color);
                    Navigator.of(context).pop();
                  },
                                           child: Container(
                           decoration: BoxDecoration(
                             color: color,
                             shape: BoxShape.circle,
                             border: Border.all(
                               color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.outline,
                               width: isSelected ? 3 : 1,
                             ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            
            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                                                        child: Text(
                         'cancel'.tr(),
                         style: TextStyle(
                           color: Theme.of(context).colorScheme.onSurfaceVariant,
                           fontSize: 16,
                         ),
                       ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 