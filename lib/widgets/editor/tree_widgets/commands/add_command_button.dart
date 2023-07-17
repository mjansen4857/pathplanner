import 'package:flutter/material.dart';

class AddCommandButton extends StatelessWidget {
  final ValueChanged<String> onTypeChosen;

  const AddCommandButton({
    super.key,
    required this.onTypeChosen,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton(
      tooltip: 'Add Command',
      icon: Icon(Icons.add, color: colorScheme.primary),
      itemBuilder: (context) => _getMenuEntries(),
      position: PopupMenuPosition.under,
      onSelected: (value) {
        onTypeChosen.call(value);
      },
    );

    // return Row(
    //   children: [
    //     Expanded(child: Container()),
    //     ClipRRect(
    //       borderRadius: BorderRadius.circular(20),
    //       child: Material(
    //         color: colorScheme.primaryContainer,
    //         child: SizedBox(
    //           height: 32,
    //           child: InkWell(
    //             onTapDown: (details) async {
    //               String? chosenValue = await showMenu(
    //                 context: context,
    //                 position: RelativeRect.fromLTRB(
    //                     details.globalPosition.dx,
    //                     details.globalPosition.dy,
    //                     details.globalPosition.dx,
    //                     0),
    //                 items: _getMenuEntries(),
    //               );
    //               if (chosenValue != null) {
    //                 onTypeChosen.call(chosenValue);
    //               }
    //             },
    //             child: const Row(
    //               children: [
    //                 SizedBox(width: 16),
    //                 Icon(Icons.arrow_drop_down),
    //                 SizedBox(width: 8),
    //                 Text('Add Command'),
    //                 SizedBox(width: 24),
    //               ],
    //             ),
    //           ),
    //         ),
    //       ),
    //     ),
    //     Expanded(child: Container()),
    //   ],
    // );
  }

  List<PopupMenuEntry<String>> _getMenuEntries() {
    return const [
      PopupMenuItem(
        value: 'named',
        child: Text('Named Command'),
      ),
      PopupMenuItem(
        value: 'wait',
        child: Text('Wait Command'),
      ),
      PopupMenuItem(
        value: 'sequential',
        child: Text('Sequential Command Group'),
      ),
      // PopupMenuItem(
      //   value: 'parallel',
      //   child: Text('Parallel Command Group'),
      // ),
      // PopupMenuItem(
      //   value: 'deadline',
      //   child: Text('Parallel Deadline Group'),
      // ),
      // PopupMenuItem(
      //   value: 'race',
      //   child: Text('Parallel Race Group'),
      // ),
    ];
  }
}
