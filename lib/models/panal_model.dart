// lib/models/admin_plan_model.dart

/// What a plan actually unlocks.
///
/// **Six codes, and only these six.** They are the access list the backend
/// checks; [CoursePlan.features] is the sales copy beside them. One is never
/// generated from the other - a tick list that says "Video Lectures" while the
/// entitlements omit `video_lecture` sells something the student cannot open,
/// and nothing in the UI would show it.
enum PlanEntitlement {
  mcq('mcq', 'MCQ Bank'),
  mock('mock', 'Mock Tests'),
  rapidRecall('rapid_recall', 'Rapid Recalls'),
  videoLecture('video_lecture', 'Video Lectures'),
  liveClass('live_class', 'Live Classes'),
  aiPatient('ai_patient', 'AI Patient');

  final String code;
  final String label;

  const PlanEntitlement(this.code, this.label);

  static PlanEntitlement? fromCode(String raw) {
    final value = raw.trim().toLowerCase();
    for (final e in PlanEntitlement.values) {
      if (e.code == value) return e;
    }
    return null;
  }
}

class AdminPlanModel {
  final int id;
  final int courseId;
  final String title;
  final String? description;
  final double price;
  final int durationDays;
  final bool isActive;

  /// "1 month", "45 days" - computed by the server. Rendered as sent; working
  /// it out again here would drift the moment the backend changes its wording.
  final String? durationLabel;

  final String? currency;

  /// Hex swatch behind the plan card on the pricing page.
  final String? accentColor;

  /// Sales copy, free text, shown as a tick list. Not access control.
  final List<String> features;

  /// The access list the backend enforces. See [PlanEntitlement].
  final List<PlanEntitlement> entitlements;

  final int displayOrder;

  AdminPlanModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.price,
    required this.durationDays,
    required this.isActive,
    this.durationLabel,
    this.currency,
    this.accentColor,
    this.features = const [],
    this.entitlements = const [],
    this.displayOrder = 0,
  });

  factory AdminPlanModel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final rawEntitlements = json['entitlements'];

    return AdminPlanModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      title: '${json['title'] ?? ''}',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      durationLabel: json['durationLabel'] as String?,
      currency: json['currency'] as String?,
      accentColor: json['accentColor'] as String?,
      features: rawFeatures is List
          ? [for (final f in rawFeatures) '$f'.trim()]
              .where((f) => f.isNotEmpty)
              .toList()
          : const [],
      // An unknown code is dropped rather than guessed at: a mistyped
      // entitlement must not silently become a different one.
      entitlements: rawEntitlements is List
          ? [
              for (final e in rawEntitlements)
                if (PlanEntitlement.fromCode('$e') case final match?) match,
            ]
          : const [],
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  /// The create/update body.
  ///
  /// Used for the `plans` array on course creation too, which is why it omits
  /// `id` and `courseId` - both come from the route or the parent object.
  Map<String, dynamic> toJson() => {
        'title': title.trim(),
        if (description != null && description!.trim().isNotEmpty)
          'description': description!.trim(),
        'price': price,
        'durationDays': durationDays,
        if (currency != null && currency!.trim().isNotEmpty)
          'currency': currency!.trim(),
        if (accentColor != null && accentColor!.trim().isNotEmpty)
          'accentColor': accentColor!.trim(),
        if (features.isNotEmpty) 'features': features,
        if (entitlements.isNotEmpty)
          'entitlements': [for (final e in entitlements) e.code],
        'isActive': isActive,
      };

  AdminPlanModel copyWith({
    String? title,
    String? description,
    double? price,
    int? durationDays,
    bool? isActive,
    String? currency,
    String? accentColor,
    List<String>? features,
    List<PlanEntitlement>? entitlements,
  }) =>
      AdminPlanModel(
        id: id,
        courseId: courseId,
        title: title ?? this.title,
        description: description ?? this.description,
        price: price ?? this.price,
        durationDays: durationDays ?? this.durationDays,
        isActive: isActive ?? this.isActive,
        durationLabel: durationLabel,
        currency: currency ?? this.currency,
        accentColor: accentColor ?? this.accentColor,
        features: features ?? this.features,
        entitlements: entitlements ?? this.entitlements,
        displayOrder: displayOrder,
      );
}
