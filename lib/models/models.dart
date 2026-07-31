String _string(dynamic value, [String fallback = '']) =>
    value?.toString() ?? fallback;

int _int(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? fallback;

bool _bool(dynamic value, [bool fallback = false]) => value is bool
    ? value
    : value?.toString() == 'true'
    ? true
    : fallback;

DateTime _date(dynamic value) =>
    DateTime.tryParse(_string(value)) ?? DateTime.fromMillisecondsSinceEpoch(0);

Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

class EventUpdate {
  final String id;
  final String title;
  final String content;
  final List<String> imageUrls;
  final String authorName;
  final String authorEmail;
  final int likesCount;
  final int dislikesCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EventUpdate({
    required this.id,
    required this.title,
    required this.content,
    required this.imageUrls,
    required this.authorName,
    required this.authorEmail,
    required this.likesCount,
    required this.dislikesCount,
    required this.createdAt,
    this.updatedAt,
  });

  factory EventUpdate.fromJson(Map<String, dynamic> json) {
    return EventUpdate(
      id: _string(json['id']),
      title: _string(json['title']),
      content: _string(json['content']),
      imageUrls: (json['image_urls'] as List<dynamic>? ?? const [])
          .map(_string)
          .where((url) => url.isNotEmpty)
          .toList(),
      authorName: _string(json['author_name']),
      authorEmail: _string(json['author_email']),
      likesCount: _int(json['likes_count']),
      dislikesCount: _int(json['dislikes_count']),
      createdAt: _date(json['created_at']),
      updatedAt: json['updated_at'] == null ? null : _date(json['updated_at']),
    );
  }
}

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String organizerName;
  final String organizerEmail;
  final String category;
  final String status;
  final String? formLink;
  final String? otherLink;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.organizerName,
    required this.organizerEmail,
    required this.category,
    required this.status,
    this.formLink,
    this.otherLink,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: _string(json['id']),
      title: _string(json['title']),
      description: _string(json['description']),
      startTime: _date(json['start_time']),
      endTime: _date(json['end_time']),
      organizerName: _string(json['organizer_name']),
      organizerEmail: _string(json['organizer_email']),
      category: _string(json['category'], 'OTHER'),
      status: _string(json['status'], 'UPCOMING'),
      formLink: json['form_link']?.toString(),
      otherLink: json['other_link']?.toString(),
    );
  }
}

class BudgetAllocation {
  final String id;
  final String house;
  final String region;
  final int students;
  final int equalShare;
  final int propShare;
  final int totalBudget;

  BudgetAllocation({
    required this.id,
    required this.house,
    required this.region,
    required this.students,
    required this.equalShare,
    required this.propShare,
    required this.totalBudget,
  });

  factory BudgetAllocation.fromJson(Map<String, dynamic> json) {
    return BudgetAllocation(
      id: _string(json['id']),
      house: _string(json['house']),
      region: _string(json['region']),
      students: _int(json['students']),
      equalShare: _int(json['equal_share']),
      propShare: _int(json['prop_share']),
      totalBudget: _int(json['total_budget']),
    );
  }
}

class UserProfile {
  final String email;
  final String displayName;
  final List<Responsibility> responsibilities;

  UserProfile({
    required this.email,
    required this.displayName,
    required this.responsibilities,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    final resps = json['responsibilities'] as List<dynamic>? ?? [];
    return UserProfile(
      email: profile['email'] as String? ?? '',
      displayName:
          profile['display_name'] as String? ??
          profile['email']?.toString().split('@').first ??
          '',
      responsibilities: resps
          .map((r) => Responsibility.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Responsibility {
  final String id;
  final String positionName;
  final String? organization;
  final String startDate;
  final String? endDate;
  final String? description;

  Responsibility({
    required this.id,
    required this.positionName,
    this.organization,
    required this.startDate,
    this.endDate,
    this.description,
  });

  factory Responsibility.fromJson(Map<String, dynamic> json) {
    return Responsibility(
      id: json['id']?.toString() ?? '',
      positionName: json['position_name'] as String? ?? '',
      organization: json['organization'] as String?,
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String?,
      description: json['description'] as String?,
    );
  }
}

class VoicesGroup {
  final String id;
  final String? groupId;
  final String name;
  final String type;

  VoicesGroup({
    required this.id,
    this.groupId,
    required this.name,
    required this.type,
  });

  factory VoicesGroup.fromJson(Map<String, dynamic> json) {
    return VoicesGroup(
      id: json['id'] as String,
      groupId: json['group_id'] as String?,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'HOUSE',
    );
  }
}

class StudentProfile {
  final String id;
  final String fullName;
  final String email;
  final String? github;
  final String? linkedin;
  final String? leetcode;
  final bool isPublic;
  final VoicesGroup? house;
  final RegionInfo? region;

  StudentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.github,
    this.linkedin,
    this.leetcode,
    required this.isPublic,
    this.house,
    this.region,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      github: json['github'] as String?,
      linkedin: json['linkedin'] as String?,
      leetcode: json['leetcode'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      house: json['house'] != null
          ? VoicesGroup.fromJson(json['house'] as Map<String, dynamic>)
          : null,
      region: json['region'] != null
          ? RegionInfo.fromJson(json['region'] as Map<String, dynamic>)
          : null,
    );
  }
}

class RegionInfo {
  final String? id;
  final String name;
  final String? code;

  RegionInfo({this.id, required this.name, this.code});

  factory RegionInfo.fromJson(Map<String, dynamic> json) {
    return RegionInfo(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
    );
  }
}

class StudentSociety {
  final String groupId;
  final String societyId;
  final String name;
  final String? category;
  final bool isActive;

  StudentSociety({
    required this.groupId,
    required this.societyId,
    required this.name,
    this.category,
    required this.isActive,
  });

  factory StudentSociety.fromJson(Map<String, dynamic> json) {
    return StudentSociety(
      groupId: json['group_id'] as String? ?? '',
      societyId: json['society_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class SocietyFilterItem {
  final String id;
  final String groupId;
  final String name;
  final String type;
  final String? societyType;

  SocietyFilterItem({
    required this.id,
    required this.groupId,
    required this.name,
    required this.type,
    this.societyType,
  });

  factory SocietyFilterItem.fromJson(Map<String, dynamic> json) {
    return SocietyFilterItem(
      id: json['id'] as String? ?? json['society_id'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'SOCIETY',
      societyType: json['society_type'] as String?,
    );
  }
}

class Comment {
  final String id;
  final String content;
  final String? createdAt;
  final String groupId;
  final String? parentId;
  final int depth;
  final int upvotesCount;
  final int downvotesCount;
  final int replyCount;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.content,
    this.createdAt,
    required this.groupId,
    this.parentId,
    required this.depth,
    required this.upvotesCount,
    required this.downvotesCount,
    this.replyCount = 0,
    required this.replies,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final list = json['replies'] as List<dynamic>? ?? [];
    return Comment(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      groupId: json['group_id'] as String? ?? '',
      parentId: json['parent_id'] as String?,
      depth: json['depth'] as int? ?? 0,
      upvotesCount: json['upvotes_count'] as int? ?? 0,
      downvotesCount: json['downvotes_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      replies: list
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CommunityGroup {
  const CommunityGroup({
    required this.id,
    required this.name,
    required this.type,
    this.groupId,
    this.societyId,
    this.societyType,
  });

  final String id;
  final String name;
  final String type;

  final String? groupId;
  final String? societyId;
  final String? societyType;

  factory CommunityGroup.fromJson(Map<String, dynamic> json) => CommunityGroup(
    id: _string(json['id']),
    name: _string(json['name']),
    type: _string(json['type'], 'GROUP'),
    groupId: json['group_id']?.toString(),
    societyId: json['society_id']?.toString(),
    societyType: json['society_type']?.toString(),
  );
}

class Election {
  const Election({
    required this.id,
    required this.title,
    required this.description,
    required this.position,
    required this.status,
    required this.eligible,
    required this.nominated,
    required this.voted,
    this.nominationStart,
    this.nominationEnd,
    this.votingStart,
    this.votingEnd,
    this.term,
    this.candidateStatus,
    this.reviewReason,
  });

  final String id;
  final String title;
  final String description;
  final String position;
  final String status;
  final bool eligible;
  final bool nominated;
  final bool voted;
  final DateTime? nominationStart;
  final DateTime? nominationEnd;
  final DateTime? votingStart;
  final DateTime? votingEnd;
  final String? term;
  final String? candidateStatus;
  final String? reviewReason;

  factory Election.fromJson(Map<String, dynamic> json) => Election(
    id: _string(json['id']),
    title: _string(json['title']),
    description: _string(json['description']),
    position: _string(json['position']),
    status: _string(json['status']),
    eligible: _bool(json['eligible']),
    nominated: _bool(json['nominated']),
    voted: _bool(json['voted']),
    nominationStart: json['nomination_start'] == null
        ? null
        : _date(json['nomination_start']),
    nominationEnd: json['nomination_end'] == null
        ? null
        : _date(json['nomination_end']),
    votingStart: json['voting_start'] == null
        ? null
        : _date(json['voting_start']),
    votingEnd: json['voting_end'] == null ? null : _date(json['voting_end']),
    term: json['term']?.toString(),
    candidateStatus: json['candidate_status']?.toString(),
    reviewReason: json['review_reason']?.toString(),
  );
}

class ElectionCandidate {
  const ElectionCandidate({
    required this.id,
    required this.name,
    required this.manifesto,
    this.assetUrl,
  });

  final String id;
  final String name;
  final String manifesto;
  final String? assetUrl;

  factory ElectionCandidate.fromJson(Map<String, dynamic> json) =>
      ElectionCandidate(
        id: _string(json['id']),
        name: _string(
          json['student_name'],
          _string(json['full_name'], 'Candidate'),
        ),
        manifesto: _string(json['manifesto']),
        assetUrl:
            json['manifesto_asset_url']?.toString() ??
            json['asset_url']?.toString(),
      );
}

class RecruitmentForm {
  const RecruitmentForm({
    required this.slug,
    required this.title,
    required this.description,
    required this.fields,
    this.deadline,
    this.alreadyApplied = false,
  });

  final String slug;
  final String title;
  final String description;
  final List<RecruitmentField> fields;
  final DateTime? deadline;
  final bool alreadyApplied;

  factory RecruitmentForm.fromJson(Map<String, dynamic> json) {
    final form = _map(json['form'] ?? json['recruitment'] ?? json);
    final rawFields =
        form['form_schema'] ??
        form['fields'] ??
        json['form_schema'] ??
        json['fields'] ??
        const [];
    final items = rawFields is List
        ? rawFields
              .map((field) => RecruitmentField.fromJson(_map(field)))
              .toList()
        : <RecruitmentField>[];
    return RecruitmentForm(
      slug: _string(form['slug'], _string(json['slug'])),
      title: _string(form['title'], _string(json['title'], 'Recruitment')),
      description: _string(form['description'], _string(json['description'])),
      fields: items,
      deadline: form['deadline'] == null ? null : _date(form['deadline']),
      alreadyApplied: _bool(json['already_applied'] ?? form['already_applied']),
    );
  }
}

class RecruitmentField {
  const RecruitmentField({
    required this.id,
    required this.label,
    required this.type,
    required this.required,
    this.helpText,
    this.options = const [],
  });

  final String id;
  final String label;
  final String type;
  final bool required;
  final String? helpText;
  final List<String> options;

  factory RecruitmentField.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] ?? json['choices'] ?? const [];
    return RecruitmentField(
      id: _string(json['id'], _string(json['key'])),
      label: _string(json['label'], _string(json['title'], 'Question')),
      type: _string(json['type'], 'text'),
      required: _bool(json['required']),
      helpText:
          json['help_text']?.toString() ?? json['description']?.toString(),
      options: rawOptions is List
          ? rawOptions
                .map(
                  (option) => option is Map
                      ? _string(option['label'], _string(option['value']))
                      : _string(option),
                )
                .toList()
          : const [],
    );
  }
}

class ChatSource {
  const ChatSource({required this.title, this.heading, this.docId});

  final String title;
  final String? heading;
  final String? docId;

  factory ChatSource.fromJson(Map<String, dynamic> json) => ChatSource(
    title: _string(json['title'], 'Source'),
    heading: json['heading']?.toString(),
    docId: json['doc_id']?.toString(),
  );
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.sources = const [],
    this.turnId,
  });

  final String role;
  final String content;
  final List<ChatSource> sources;
  final String? turnId;
}
