package project.service;

import org.json.JSONArray;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class ChatBotService {

    private static final Logger logger = LoggerFactory.getLogger(ChatBotService.class);

    @Value("${huggingface.api.url}")
    private String API_URL;

    @Value("${huggingface.api.key}")
    private String API_KEY;

    @Value("${chatbot.cache.timeout}")
    private long cacheTimeoutSeconds;

    // In-memory cache: question -> {answer, timestamp}
    private final Map<String, CacheEntry> answerCache = new ConcurrentHashMap<>();

    private static class CacheEntry {
        String answer;
        long timestamp;

        CacheEntry(String answer, long timestamp) {
            this.answer = answer;
            this.timestamp = timestamp;
        }
    }

    public String ask(String question) {
        try {
            // Normalize question for cache key (trim, lowercase)
            String cacheKey = question.trim().toLowerCase();

            // Check cache
            CacheEntry cached = answerCache.get(cacheKey);
            if (cached != null) {
                long currentTime = System.currentTimeMillis() / 1000;
                if (currentTime - cached.timestamp < cacheTimeoutSeconds) {
                    logger.debug("Returning cached answer for question: {}", question);
                    return cached.answer;
                } else {
                    logger.debug("Cache expired for question: {}", question);
                    answerCache.remove(cacheKey);
                }
            }

            String prompt = """
You are 9antraBot, a helpful AI tutor on the 9antra e-learning platform. Your role is to assist students by answering their questions about the platform or their learning in a clear, accurate, and beginner-friendly way.

**About 9antra**:
- Students can enroll in online courses, follow instructors, bookmark courses, leave reviews, track progress, and join live sessions.
- Instructors create courses and live sessions; some sessions are restricted to followers only (using 100ms video).
- Features include profile management, two-factor authentication, and course progress tracking.

**Instructions**:
- Answer **only** the question asked, providing a direct, complete, and focused response.
- Do not include additional questions, promotional content (e.g., "Join 9antra"), speculative follow-ups, or references to 9antra unless the question is about the platform.
- For platform questions (e.g., "How do I follow an instructor?" or "How do I join a session?"), describe the steps clearly, referencing 9antra’s features.
- For learning questions (e.g., "What is a class in Java?"), provide a clear explanation with examples if relevant.
- If the question is unclear or unrelated, politely ask for clarification or give a brief educational response.
- Keep answers concise, informative, and free of jargon.
- Stop immediately after answering the question.

Question: """ + question + """

Answer:
""";

            JSONObject body = new JSONObject();
            body.put("inputs", prompt);
            // Add parameters for Mixtral
            JSONObject parameters = new JSONObject();
            parameters.put("max_new_tokens", 600); // For complete answers
            parameters.put("temperature", 0.7); // Balanced creativity
            parameters.put("top_p", 0.9); // Focused answers
            body.put("parameters", parameters);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(API_URL))
                    .header("Authorization", "Bearer " + API_KEY)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                    .build();

            // Retry up to 3 times
            for (int attempt = 1; attempt <= 3; attempt++) {
                try {
                    logger.debug("Sending request to Hugging Face API, attempt {}", attempt);
                    HttpResponse<String> response = HttpClient.newHttpClient()
                            .send(request, HttpResponse.BodyHandlers.ofString());
                    String responseBody = response.body();
                    logger.debug("Received response: {}", responseBody);

                    // Handle JSONArray response
                    if (responseBody.trim().startsWith("[")) {
                        JSONArray arr = new JSONArray(responseBody);
                        if (!arr.isEmpty()) {
                            String generatedText = arr.getJSONObject(0).getString("generated_text");
                            // Extract answer
                            String answer = generatedText.replace(prompt, "").trim();
                            // Strip extra content
                            if (answer.contains("Question:") || answer.contains("Learn 9antra") || answer.contains("Enroll in")) {
                                answer = answer.split("Question:|Learn 9antra|Enroll in")[0].trim();
                            }
                            // Normalize whitespace
                            answer = answer.replaceAll("\\s+", " ");

                            // Cache the answer
                            answerCache.put(cacheKey, new CacheEntry(answer, System.currentTimeMillis() / 1000));
                            logger.debug("Cached answer for question: {}", question);

                            return answer;
                        } else {
                            logger.warn("Empty response array from API");
                            return "The model didn't return a response.";
                        }
                    }

                    // Handle error response
                    JSONObject obj = new JSONObject(responseBody);
                    if (obj.has("error")) {
                        String error = obj.getString("error");
                        logger.error("API error: {}", error);
                        if (error.contains("Model is overloaded") && attempt < 3) {
                            logger.info("Model overloaded, retrying after {} ms...", 2000 * attempt);
                            Thread.sleep(2000L * attempt); // Exponential backoff
                            continue;
                        }
                        if (error.contains("exceeded your monthly included credits")) {
                            return "Sorry, the chatbot’s API credits are used up for this month. Please try again later.";
                        }
                        if (error.contains("Rate limit")) {
                            return "Sorry, the chatbot is busy right now. Please try again in a few minutes.";
                        }
                        return "Error from Hugging Face API: " + error;
                    } else if (obj.has("message")) {
                        logger.warn("API message: {}", obj.getString("message"));
                        return "Hugging Face response: " + obj.getString("message");
                    }

                    logger.warn("Unexpected response format: {}", responseBody);
                    return "Unexpected response format.";
                } catch (Exception e) {
                    logger.error("Request failed on attempt {}: {}", attempt, e.getMessage());
                    if (attempt == 3) {
                        return "Failed after retries: " + e.getMessage();
                    }
                    Thread.sleep(2000L * attempt); // Exponential backoff
                }
            }
            logger.error("Failed to get a response after 3 retries");
            return "Failed to get a response after retries.";
        } catch (Exception e) {
            logger.error("Unexpected error: {}", e.getMessage());
            return "Something went wrong: " + e.getMessage();
        }
    }
}