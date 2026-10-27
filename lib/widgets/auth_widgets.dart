import 'package:flutter/material.dart';

const olive = Color(0xFF707B55);
const ink = Color(0xFF202B42);

class Frame extends StatelessWidget {
  const Frame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SafeArea(child: child),
      ),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: olive,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.large = false, this.url = ''});
  final bool large;
  final String url;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: large ? 45 : 30,
    backgroundColor: const Color(0xFFE7DEC9),
    child: ClipOval(
      child: url.isEmpty
          ? Icon(Icons.person_rounded, size: large ? 65 : 40, color: olive)
          : Image.network(
              url,
              width: large ? 90 : 60,
              height: large ? 90 : 60,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => Icon(
                Icons.person_rounded,
                size: large ? 65 : 40,
                color: olive,
              ),
            ),
    ),
  );
}
