import 'package:flutter/material.dart';

const Duration smoothDuration = Duration(milliseconds: 1000);
const Duration stepAdvanceDuration = Duration(milliseconds: 500);
const Duration descriptionDuration = Duration(milliseconds: 200);
const Duration bouncyDuration = Duration(milliseconds: 1000);

const Curve smoothCurve = Curves.easeInOutCubic;
const Curve bouncyCurve = Curves.elasticOut;

/// Strong ease-out for routine UI state changes, used for entrances *and* exits.
///
/// Replaces `Curves.easeInCubic` on switch-outs across the app. An ease-*in*
/// exit starts slow, so a state change the user just asked for visibly hesitates
/// before leaving; on a tab switch or a prompt step that reads as lag.
const Curve strongEaseOut = Cubic(0.23, 1, 0.32, 1);

/// One timeline for a routine step/tab change. Long enough to read as a
/// direction, short enough that the arriving control is usable immediately.
const Duration stepSwitchDuration = Duration(milliseconds: 200);

/// Switch duration when `MediaQuery.disableAnimations` is set: opacity only,
/// and short.
const Duration reducedSwitchDuration = Duration(milliseconds: 120);
