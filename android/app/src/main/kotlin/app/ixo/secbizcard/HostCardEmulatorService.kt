package app.ixo.secbizcard

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import java.util.Arrays

class HostCardEmulatorService : HostApduService() {

    companion object {
        const val TAG = "HostCardEmulator"
        
        // Standard NDEF Type 4 Tag constants
        val AID_ANDROID = byteArrayOf(0xD2.toByte(), 0x76.toByte(), 0x00.toByte(), 0x00.toByte(), 0x85.toByte(), 0x01.toByte(), 0x01.toByte())
        val SELECT_INS = 0xA4.toByte()
        val READ_INS = 0xB0.toByte()
        
        // File Identifiers
        val CC_FILE_ID = byteArrayOf(0xE1.toByte(), 0x03.toByte())
        val NDEF_FILE_ID = byteArrayOf(0xE1.toByte(), 0x04.toByte())
        
        // Response Status
        val STATUS_SUCCESS = byteArrayOf(0x90.toByte(), 0x00.toByte())
        val STATUS_ERROR = byteArrayOf(0x6A.toByte(), 0x82.toByte())

        // Default CC Content (Capability Container)
        val CAPABILITY_CONTAINER = byteArrayOf(
            0x00, 0x0F, // CCLEN (15 bytes)
            0x20,       // Mapping Version 2.0
            0x00, 0x3B, // MLe (59 bytes)
            0x00, 0x34, // MLc (52 bytes)
            0x04,       // T field of the NDEF File Control TLV
            0x06,       // L field of the NDEF File Control TLV
            0xE1.toByte(), 0x04.toByte(), // File ID
            0x00, 0xFF.toByte(), // Max NDEF Size
            0x00,       // Read Access
            0x00        // Write Access
        )

        // Dynamic URL sharing
        private var sharingUrl: String = "https://ixo.app"

        fun setSharingUrl(url: String) {
            sharingUrl = url
            Log.d(TAG, "Sharing URL set to: $url")
        }
    }

    private var selectedFileId: ByteArray? = null

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "Deactivated: $reason")
        selectedFileId = null
    }

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        if (commandApdu.size < 4) return STATUS_ERROR

        val cla = commandApdu[0]
        val ins = commandApdu[1]
        val p1 = commandApdu[2]
        val p2 = commandApdu[3]

        return when (ins) {
            SELECT_INS -> handleSelect(commandApdu)
            READ_INS -> handleRead(commandApdu)
            else -> STATUS_ERROR
        }
    }

    private fun handleSelect(commandApdu: ByteArray): ByteArray {
        if (commandApdu.size < 5) return STATUS_ERROR
        val lc = commandApdu[4].toInt() and 0xFF
        if (commandApdu.size < 5 + lc) return STATUS_ERROR
        
        val payload = commandApdu.copyOfRange(5, 5 + lc)

        return when {
            Arrays.equals(payload, AID_ANDROID) -> STATUS_SUCCESS
            Arrays.equals(payload, CC_FILE_ID) -> {
                selectedFileId = CC_FILE_ID
                STATUS_SUCCESS
            }
            Arrays.equals(payload, NDEF_FILE_ID) -> {
                selectedFileId = NDEF_FILE_ID
                STATUS_SUCCESS
            }
            else -> STATUS_ERROR
        }
    }

    private fun handleRead(commandApdu: ByteArray): ByteArray {
        val offset = ((commandApdu[2].toInt() and 0xFF) shl 8) or (commandApdu[3].toInt() and 0xFF)
        val length = if (commandApdu.size > 4) (commandApdu[4].toInt() and 0xFF) else 0

        val fileContent = when {
            Arrays.equals(selectedFileId, CC_FILE_ID) -> CAPABILITY_CONTAINER
            Arrays.equals(selectedFileId, NDEF_FILE_ID) -> createNdefMessage()
            else -> return STATUS_ERROR
        }

        if (offset >= fileContent.size) return STATUS_SUCCESS // End of file

        val end = (offset + length).coerceAtMost(fileContent.size)
        val data = fileContent.copyOfRange(offset, end)
        
        return data + STATUS_SUCCESS
    }

    private fun createNdefMessage(): ByteArray {
        // NDEF URI Record for the sharing URL
        // Header: 0xD1 (MB=1, ME=1, CF=0, SR=1, IL=0, TNF=0x01 Well-Known)
        // Type Length: 0x01
        // Payload Length: url.length + 1 (for prefix)
        // Type: 0x55 ('U')
        // Payload: [Prefix Code] + [URL Suffix]
        
        val uri = sharingUrl
        val prefix = 0x04.toByte() // https://
        val suffix = if (uri.startsWith("https://")) uri.substring(8) else uri
        val suffixBytes = suffix.toByteArray(Charsets.UTF_8)
        
        val payloadLength = suffixBytes.size + 1
        val record = byteArrayOf(
            0xD1.toByte(),
            0x01.toByte(),
            payloadLength.toByte(),
            0x55.toByte(),
            prefix
        ) + suffixBytes

        // NDEF File Format: [Length (2 bytes)] + [NDEF Message]
        val totalLength = record.size
        return byteArrayOf(
            ((totalLength shr 8) and 0xFF).toByte(),
            (totalLength and 0xFF).toByte()
        ) + record
    }
}
