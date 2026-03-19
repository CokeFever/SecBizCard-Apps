import 'package:freezed_annotation/freezed_annotation.dart';

part 'verification_status.freezed.dart';

@freezed
class VerificationStatus with _$VerificationStatus {
  const factory VerificationStatus.initial() = _Initial;
  const factory VerificationStatus.codeSent({required String verificationId}) =
      _CodeSent;
  const factory VerificationStatus.verifying() = _Verifying;
  const factory VerificationStatus.verified() = _Verified;
  const factory VerificationStatus.error({required String message}) = _Error;
}
