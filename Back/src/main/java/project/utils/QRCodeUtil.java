package project.utils;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.fasterxml.jackson.databind.ObjectMapper;
import project.exception.InvalidQRCodeException;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

public class QRCodeUtil {
    public static String generateQRCodeBase64(Long eventId, Long studentId) throws WriterException, IOException {
        Map<String, Long> qrData = new HashMap<>();
        qrData.put("eventId", eventId);
        qrData.put("studentId", studentId);
        String jsonData = new ObjectMapper().writeValueAsString(qrData);

        QRCodeWriter qrCodeWriter = new QRCodeWriter();
        BitMatrix bitMatrix = qrCodeWriter.encode(jsonData, BarcodeFormat.QR_CODE, 200, 200);

        ByteArrayOutputStream pngOutputStream = new ByteArrayOutputStream();
        MatrixToImageWriter.writeToStream(bitMatrix, "PNG", pngOutputStream);
        byte[] pngData = pngOutputStream.toByteArray();

        return Base64.getEncoder().encodeToString(pngData);
    }

    public static Map<String, Long> parseQRCodeData(String qrData) throws IOException {
        try {
            Map<String, Object> map = new ObjectMapper().readValue(qrData, Map.class);
            if (!map.containsKey("eventId") || map.get("eventId") == null) {
                throw new InvalidQRCodeException("QR code missing or invalid eventId");
            }
            if (!map.containsKey("studentId") || map.get("studentId") == null) {
                throw new InvalidQRCodeException("QR code missing or invalid studentId");
            }
            Map<String, Long> result = new HashMap<>();
            Long eventId = ((Number) map.get("eventId")).longValue();
            Long studentId = ((Number) map.get("studentId")).longValue();
            if (eventId <= 0 || studentId <= 0) {
                throw new InvalidQRCodeException("eventId and studentId must be positive integers");
            }
            result.put("eventId", eventId);
            result.put("studentId", studentId);
            return result;
        } catch (IOException e) {
            throw new InvalidQRCodeException("Invalid QR code data format: " + e.getMessage());
        }
    }
}