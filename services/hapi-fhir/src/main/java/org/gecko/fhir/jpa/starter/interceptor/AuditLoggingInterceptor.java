package org.gecko.fhir.jpa.starter.interceptor;

import ca.uhn.fhir.interceptor.api.Hook;
import ca.uhn.fhir.interceptor.api.Interceptor;
import ca.uhn.fhir.interceptor.api.Pointcut;
import ca.uhn.fhir.rest.api.server.RequestDetails;
import ca.uhn.fhir.rest.server.servlet.ServletRequestDetails;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.Enumeration;

@Component
@Interceptor
public class AuditLoggingInterceptor {

    private static final Logger auditLogger = LoggerFactory.getLogger("audit");
    private static final ObjectMapper objectMapper = new ObjectMapper();
    private static final DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS")
            .withZone(ZoneId.systemDefault());

    @Hook(Pointcut.SERVER_INCOMING_REQUEST_PRE_HANDLED)
    public void auditIncomingRequest(RequestDetails theRequestDetails) {
        try {
            // Extract user information from headers set by oauth2-proxy
            String username = extractUsername(theRequestDetails);
            String userEmail = extractUserEmail(theRequestDetails);
            
            // Create audit log entry
            ObjectNode auditEntry = objectMapper.createObjectNode();
            auditEntry.put("timestamp", formatter.format(Instant.now()));
            auditEntry.put("event_type", "FHIR_REQUEST");
            auditEntry.put("username", username != null ? username : "anonymous");
            auditEntry.put("user_email", userEmail != null ? userEmail : "unknown");
            auditEntry.put("method", theRequestDetails.getRequestType().name());
            auditEntry.put("resource_type", theRequestDetails.getResourceName());
            auditEntry.put("operation", theRequestDetails.getOperation());
            auditEntry.put("request_path", theRequestDetails.getRequestPath());
            auditEntry.put("fhir_server_base", theRequestDetails.getFhirServerBase());
            
            // Add client IP address
            if (theRequestDetails instanceof ServletRequestDetails) {
                ServletRequestDetails servletDetails = (ServletRequestDetails) theRequestDetails;
                HttpServletRequest servletRequest = servletDetails.getServletRequest();
                String clientIp = getClientIpAddress(servletRequest);
                auditEntry.put("client_ip", clientIp);
                auditEntry.put("user_agent", servletRequest.getHeader("User-Agent"));
            }
            
            // Add query parameters if present
            if (theRequestDetails.getParameters() != null && !theRequestDetails.getParameters().isEmpty()) {
                ObjectNode queryParams = objectMapper.createObjectNode();
                theRequestDetails.getParameters().forEach((key, values) -> {
                    if (values != null && values.length > 0) {
                        if (values.length == 1) {
                            queryParams.put(key, values[0]);
                        } else {
                            queryParams.set(key, objectMapper.valueToTree(values));
                        }
                    }
                });
                auditEntry.set("query_parameters", queryParams);
            }
            
            // Log the structured audit entry
            auditLogger.info(auditEntry.toString());
            
        } catch (Exception e) {
            // Don't let audit logging break the request processing
            auditLogger.error("Error in audit logging: {}", e.getMessage(), e);
        }
    }
    
    @Hook(Pointcut.SERVER_OUTGOING_RESPONSE)
    public void auditOutgoingResponse(RequestDetails theRequestDetails, 
                                     ca.uhn.fhir.rest.api.server.ResponseDetails theResponseDetails, 
                                     HttpServletRequest theServletRequest,
                                     jakarta.servlet.http.HttpServletResponse theServletResponse) {
        try {
            String username = extractUsername(theRequestDetails);
            String userEmail = extractUserEmail(theRequestDetails);
            
            // Create response audit log entry
            ObjectNode auditEntry = objectMapper.createObjectNode();
            auditEntry.put("timestamp", formatter.format(Instant.now()));
            auditEntry.put("event_type", "FHIR_RESPONSE");
            auditEntry.put("username", username != null ? username : "anonymous");
            auditEntry.put("user_email", userEmail != null ? userEmail : "unknown");
            auditEntry.put("method", theRequestDetails.getRequestType().name());
            auditEntry.put("resource_type", theRequestDetails.getResourceName());
            auditEntry.put("operation", theRequestDetails.getOperation());
            auditEntry.put("request_path", theRequestDetails.getRequestPath());
            auditEntry.put("response_code", theResponseDetails.getResponseCode());
            
            // Add resource count for search operations
            if (theResponseDetails.getResponseResource() != null) {
                String resourceType = theResponseDetails.getResponseResource().getClass().getSimpleName();
                auditEntry.put("response_resource_type", resourceType);
                
                // For Bundle responses (search results), log the number of entries
                if ("Bundle".equals(resourceType)) {
                    try {
                        org.hl7.fhir.instance.model.api.IBaseBundle bundle = 
                            (org.hl7.fhir.instance.model.api.IBaseBundle) theResponseDetails.getResponseResource();
                        // This is a generic way to get bundle size that works across FHIR versions
                        if (bundle instanceof org.hl7.fhir.r4.model.Bundle) {
                            org.hl7.fhir.r4.model.Bundle r4Bundle = (org.hl7.fhir.r4.model.Bundle) bundle;
                            auditEntry.put("bundle_entries_count", r4Bundle.getEntry().size());
                            auditEntry.put("bundle_total", r4Bundle.getTotal());
                        }
                    } catch (Exception e) {
                        // Ignore errors in bundle parsing
                    }
                }
            }
            
            if (theServletRequest != null) {
                String clientIp = getClientIpAddress(theServletRequest);
                auditEntry.put("client_ip", clientIp);
            }
            
            // Log the structured audit entry
            auditLogger.info(auditEntry.toString());
            
        } catch (Exception e) {
            // Don't let audit logging break the response processing
            auditLogger.error("Error in response audit logging: {}", e.getMessage(), e);
        }
    }
    
    /**
     * Extract username from JWT token in Authorization header
     */
    private String extractUsername(RequestDetails theRequestDetails) {
        try {
            // Get the Authorization header with the JWT token
            String authHeader = theRequestDetails.getHeader("Authorization");
            if (authHeader != null && authHeader.startsWith("Bearer ")) {
                String jwtToken = authHeader.substring(7); // Remove "Bearer " prefix
                
                // Parse JWT token to get preferred_username
                String username = parseJwtForUsername(jwtToken);
                if (username != null) {
                    return username;
                }
            }
            
            // Fallback to other headers
            String fallbackUsername = theRequestDetails.getHeader("X-User");
            if (fallbackUsername == null || fallbackUsername.trim().isEmpty()) {
                fallbackUsername = theRequestDetails.getHeader("X-Auth-Request-User");
            }
            
            return fallbackUsername != null && !fallbackUsername.trim().isEmpty() ? fallbackUsername.trim() : null;
            
        } catch (Exception e) {
            auditLogger.error("Error extracting username from JWT: {}", e.getMessage());
            return null;
        }
    }
    
    /**
     * Parse JWT token to extract preferred_username claim
     */
    private String parseJwtForUsername(String jwtToken) {
        try {
            // JWT has 3 parts separated by dots: header.payload.signature
            String[] parts = jwtToken.split("\\.");
            if (parts.length != 3) {
                return null;
            }
            
            // Decode the payload (second part)
            String payload = parts[1];
            
            // Add padding if needed for Base64 decoding
            while (payload.length() % 4 != 0) {
                payload += "=";
            }
            
            byte[] decodedBytes = Base64.getUrlDecoder().decode(payload);
            String decodedPayload = new String(decodedBytes);
            
            // Parse JSON payload
            JsonNode payloadJson = objectMapper.readTree(decodedPayload);
            
            // Extract preferred_username claim
            JsonNode preferredUsernameNode = payloadJson.get("preferred_username");
            if (preferredUsernameNode != null && !preferredUsernameNode.isNull()) {
                return preferredUsernameNode.asText();
            }
            
            // Fallback to "name" claim if preferred_username is not available
            JsonNode nameNode = payloadJson.get("name");
            if (nameNode != null && !nameNode.isNull()) {
                return nameNode.asText();
            }
            
            // Fallback to "sub" claim as last resort
            JsonNode subNode = payloadJson.get("sub");
            if (subNode != null && !subNode.isNull()) {
                return subNode.asText();
            }
            
            return null;
            
        } catch (Exception e) {
            auditLogger.error("Error parsing JWT token: {}", e.getMessage());
            return null;
        }
    }
    
    /**
     * Extract user email from request headers set by oauth2-proxy
     */
    private String extractUserEmail(RequestDetails theRequestDetails) {
        // oauth2-proxy sets the email in X-Email header
        String email = theRequestDetails.getHeader("X-Email");
        if (email == null || email.trim().isEmpty()) {
            // Fallback to X-Auth-Request-Email header
            email = theRequestDetails.getHeader("X-Auth-Request-Email");
        }
        return email != null && !email.trim().isEmpty() ? email.trim() : null;
    }
    
    /**
     * Get the real client IP address, considering proxy headers
     */
    private String getClientIpAddress(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            // X-Forwarded-For can contain multiple IPs, the first one is the original client
            return xForwardedFor.split(",")[0].trim();
        }
        
        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isEmpty()) {
            return xRealIp;
        }
        
        return request.getRemoteAddr();
    }
}
