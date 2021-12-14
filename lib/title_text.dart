import 'package:flutter/material.dart';
import 'data_classes.dart';

class TitleText extends StatelessWidget {
  const TitleText({
    Key? key,
    required Info state,
    required this.context,
  }) : _info = state, super(key: key);

  final Info _info;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        _info.info ?? "-",
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 3,
        overflow: TextOverflow.fade,
        style: Theme.of(context).textTheme.headline1,
      ),
    );
  }
}
