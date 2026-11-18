import 'package:flutter/material.dart';

const Color couleurARevoir = Color(0xFFC62828);

/// Case « À revoir » avec une note facultative, pour les formulaires.
class ChampARevoir extends StatelessWidget {
  const ChampARevoir({super.key, required this.valeur, required this.note, required this.onChange});
  final bool valeur;
  final TextEditingController note;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: valeur ? const Color(0xFFFFEBEE) : null,
        border: Border.all(color: valeur ? couleurARevoir : Colors.black26, width: valeur ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          secondary: Icon(Icons.flag, color: valeur ? couleurARevoir : Colors.grey),
          title: const Text('À revoir', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Écriture ou prix pas clair : à vérifier plus tard'),
          value: valeur,
          activeThumbColor: couleurARevoir,
          onChanged: onChange,
        ),
        if (valeur)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextField(
              controller: note,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Note (facultatif)',
                hintText: 'ex. prix illisible, quantité douteuse',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
      ]),
    );
  }
}

/// Dans une liste : une bande rouge « À REVOIR » au-dessus de la ligne et un fond rosé.
Widget avecMarqueARevoir({required bool aRevoir, required String note, required Widget child}) {
  if (!aRevoir) return child;
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(
      color: couleurARevoir,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        const Icon(Icons.flag, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            note.trim().isEmpty ? 'À REVOIR' : 'À REVOIR : ${note.trim()}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ]),
    ),
    Container(color: const Color(0xFFFFEBEE), child: child),
  ]);
}

/// Bandeau en haut de l'écran : combien d'éléments restent à revoir.
Widget bandeauNombreARevoir(int n) {
  if (n == 0) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    color: couleurARevoir,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      const Icon(Icons.flag, color: Colors.white),
      const SizedBox(width: 8),
      Expanded(
        child: Text('$n à revoir',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    ]),
  );
}
