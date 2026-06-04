// lib/widgets/adaptive_avatar_grid.dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_typography.dart';

/// Un elemento (jugador) a mostrar como cara en la rejilla.
class AvatarItem {
  const AvatarItem({required this.id, required this.label, this.color});
  final String id;
  final String label;
  final Color? color;
}

/// Columnas + tamaño de celda (cara) elegidos para llenar el área.
class GridLayout {
  const GridLayout(this.columns, this.cell);
  final int columns;
  final double cell;
}

/// Elige columnas y tamaño de cara para que [count] caras llenen el área
/// [maxWidth]x[maxHeight] de la forma más simétrica posible (maximiza el
/// tamaño de cara que cabe en ambos ejes), sin superar [maxCell]. Las filas
/// parciales se centran en el widget → resultado equilibrado, sin huecos.
GridLayout computeAvatarLayout({
  required int count,
  required double maxWidth,
  required double maxHeight,
  double spacing = 10,
  double maxCell = 72,
  double labelHeight = 16,
}) {
  if (count <= 0 || maxWidth <= 0 || maxHeight <= 0) {
    return const GridLayout(1, 0);
  }
  var bestCols = 1;
  var bestCell = 0.0;
  for (var cols = 1; cols <= count; cols++) {
    final rows = (count / cols).ceil();
    final cellW = (maxWidth - spacing * (cols - 1)) / cols;
    final cellH = (maxHeight - spacing * (rows - 1)) / rows - labelHeight;
    final cell = cellW < cellH ? cellW : cellH;
    if (cell > bestCell) {
      bestCell = cell;
      bestCols = cols;
    }
  }
  if (bestCell < 0) bestCell = 0;
  if (bestCell > maxCell) bestCell = maxCell;
  return GridLayout(bestCols, bestCell);
}

/// Rejilla de caras que se adapta al espacio: usa [computeAvatarLayout] para
/// elegir columnas y tamaño, y centra cada fila (incluida la última) para que
/// no queden huecos a un lado. Llama [onTap] al tocar una cara.
class AdaptiveAvatarGrid extends StatelessWidget {
  const AdaptiveAvatarGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.selectedId,
    this.spacing = 10,
    this.maxCell = 72,
  });

  final List<AvatarItem> items;
  final void Function(AvatarItem) onTap;
  final String? selectedId;
  final double spacing;
  final double maxCell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = computeAvatarLayout(
          count: items.length,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          spacing: spacing,
          maxCell: maxCell,
        );
        final cols = layout.columns;
        final cell = layout.cell;

        final rows = <List<AvatarItem>>[];
        for (var i = 0; i < items.length; i += cols) {
          rows.add(items.sublist(
              i, (i + cols > items.length) ? items.length : i + cols));
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final item in row)
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: spacing / 2),
                          child: _AvatarCell(
                            item: item,
                            size: cell,
                            selected: item.id == selectedId,
                            onTap: () => onTap(item),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarCell extends StatelessWidget {
  const _AvatarCell({
    required this.item,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final AvatarItem item;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = item.color ?? AppColors.danger;
    final inicial = item.label.isNotEmpty ? item.label[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : AppColors.surfaceHigh,
                border: Border.all(
                  color: selected ? accent : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Text(
                inicial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.38,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: size + 8,
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppType.bodyS.copyWith(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
