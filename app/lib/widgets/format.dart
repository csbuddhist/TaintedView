String formatChars(int chars) =>
    chars >= 10000 ? '${(chars / 10000).toStringAsFixed(1)} 万字' : '$chars 字';
