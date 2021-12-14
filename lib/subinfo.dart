import 'package:flutter/material.dart';
import 'data_classes.dart';

class SubInfoList extends StatelessWidget {
  const SubInfoList({
    Key? key,
    required this.context,
    required this.subInfos,
  }) : super(key: key);

  final BuildContext context;
  final List<SubInfo> subInfos;

  @override
  Widget build(BuildContext context) {
    var children = subInfos.map((si) => SubInfoRow(context: context, subInfo: si)).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class SubInfoRow extends StatelessWidget {
  const SubInfoRow({
    Key? key,
    required this.context,
    required this.subInfo,
  }) : super(key: key);

  final BuildContext context;
  final SubInfo subInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: subInfo.key,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(
            infoTypeToIcon(subInfo.type),
            size: Theme.of(context).textTheme.headline2?.fontSize,
          ),
        ),
        Flexible(
          child: Text(
            subInfo.text,
            textAlign: TextAlign.left,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            maxLines: 2,
            style: Theme.of(context).textTheme.headline2,
          ),
        ),
      ],
    );
  }

  IconData infoTypeToIcon(InfoType type) {
    switch (type) {
      case InfoType.album:
        return Icons.album;
      case InfoType.composer:
        return Icons.edit;
      case InfoType.performer:
        return Icons.piano;
      default:
        return Icons.device_unknown;
    }
  }
}
