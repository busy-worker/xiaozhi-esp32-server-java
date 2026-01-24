package com.xiaozhi.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import com.github.pagehelper.PageInfo;
import com.xiaozhi.common.web.ResultMessage;
import com.xiaozhi.common.web.PageFilter;
import com.xiaozhi.dialogue.stt.factory.SttServiceFactory;
import com.xiaozhi.dialogue.tts.TtsService;
import com.xiaozhi.dialogue.tts.factory.TtsServiceFactory;
import com.xiaozhi.entity.SysConfig;
import com.xiaozhi.service.SysConfigService;
import com.xiaozhi.utils.CmsUtils;

import cn.dev33.satoken.annotation.SaIgnore;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.annotation.Resource;
import jakarta.servlet.http.HttpServletRequest;

import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 配置管理
 * 
 * @author Joey
 * 
 */

@RestController
@RequestMapping("/api/config")
@Tag(name = "配置管理", description = "配置相关操作")
public class ConfigController extends BaseController {

    @Resource
    private SysConfigService configService;

    @Resource
    private TtsServiceFactory ttsServiceFactory;

    @Resource
    private SttServiceFactory sttServiceFactory;

    /**
     * 配置查询
     * 
     * @param config
     * @return configList
     */
    @GetMapping("/query")
    @ResponseBody
    @Operation(summary = "根据条件查询配置", description = "返回配置信息列表")
    public ResultMessage query(SysConfig config, HttpServletRequest request) {
        try {
            PageFilter pageFilter = initPageFilter(request);
            List<SysConfig> configList = configService.query(config, pageFilter);
            ResultMessage result = ResultMessage.success();
            result.put("data", new PageInfo<>(configList));
            return result;
        } catch (Exception e) {
            logger.error(e.getMessage(), e);
            return ResultMessage.error();
        }
    }

    /**
     * 配置信息更新
     * 
     * @param config
     * @return
     */
    @PostMapping("/update")
    @ResponseBody
    @Operation(summary = "更新配置信息", description = "返回更新结果")
    public ResultMessage update(SysConfig config) {
        try {
            config.setUserId(CmsUtils.getUserId());
            SysConfig oldSysConfig = configService.selectConfigById(config.getConfigId());
            int rows = configService.update(config);
            if (rows > 0) {
                if (oldSysConfig != null) {
                    if ("stt".equals(oldSysConfig.getConfigType())
                            && !oldSysConfig.getApiKey().equals(config.getApiKey())) {
                        sttServiceFactory.removeCache(oldSysConfig);
                    } else if ("tts".equals(oldSysConfig.getConfigType())
                            && !oldSysConfig.getApiKey().equals(config.getApiKey())) {
                        ttsServiceFactory.removeCache(oldSysConfig);
                    }
                }
            }
            return ResultMessage.success();
        } catch (Exception e) {
            logger.error(e.getMessage(), e);
            return ResultMessage.error();
        }
    }

    /**
     * 添加配置
     * 
     * @param config
     */
    @PostMapping("/add")
    @ResponseBody
    @Operation(summary = "添加配置信息", description = "返回添加结果")
    public ResultMessage add(SysConfig config) {
        try {
            config.setUserId(CmsUtils.getUserId());
            configService.add(config);
            return ResultMessage.success();
        } catch (Exception e) {
            logger.error(e.getMessage(), e);
            return ResultMessage.error();
        }
    }

    @PostMapping("/getModels")
    @ResponseBody
    @Operation(summary = "获取模型列表", description = "返回模型列表")
    public ResultMessage getModels(SysConfig config) {
        try {
            RestTemplate restTemplate = new RestTemplate();
            // 设置请求头
            HttpHeaders headers = new HttpHeaders();
            headers.set("Authorization", "Bearer " + config.getApiKey());

            // 构建请求实体
            HttpEntity<String> entity = new HttpEntity<>(headers);

            // 调用 /v1/models 接口，解析为 JSON 字符串
            ResponseEntity<String> response = restTemplate.exchange(
                    config.getApiUrl() + "/models",
                    HttpMethod.GET,
                    entity,
                    String.class);

            // 使用 ObjectMapper 解析 JSON 响应
            ObjectMapper objectMapper = new ObjectMapper();
            JsonNode rootNode = objectMapper.readTree(response.getBody());

            // 提取 "data" 字段
            JsonNode dataNode = rootNode.get("data");
            if (dataNode == null || !dataNode.isArray()) {
                return ResultMessage.error("响应数据格式错误，缺少 data 字段或 data 不是数组");
            }

            // 将 "data" 字段解析为 List<Map<String, Object>>
            List<Map<String, Object>> modelList = objectMapper.convertValue(
                    dataNode,
                    new TypeReference<List<Map<String, Object>>>() {
                    });

            // 返回成功结果
            ResultMessage result = ResultMessage.success();
            result.put("data", modelList);
            return result;

        } catch (HttpClientErrorException e) {
            // 捕获 HTTP 客户端异常并返回详细错误信息
            String errorMessage = e.getResponseBodyAsString();
            // 返回详细错误信息到前端
            return ResultMessage.error("调用模型接口失败: " + errorMessage);

        } catch (Exception e) {
            // 捕获其他异常并记录日志
            return ResultMessage.error();
        }
    }

    /**
     * TTS调试接口 - 用于测试TTS服务
     * 
     * @param requestBody 包含text(必填), ttsId(可选), voiceName(可选), pitch(可选), speed(可选)
     * @return TTS生成结果
     */
    @SaIgnore
    @PostMapping("/debug/tts")
    @ResponseBody
    @Operation(summary = "TTS调试接口", description = "用于测试TTS服务，输出详细日志")
    public ResultMessage debugTts(@RequestBody Map<String, Object> requestBody) {
        long startTime = System.currentTimeMillis();
        String text = (String) requestBody.get("text");
        Integer ttsId = requestBody.get("ttsId") != null ? 
                (requestBody.get("ttsId") instanceof Integer ? (Integer) requestBody.get("ttsId") : 
                 Integer.parseInt(requestBody.get("ttsId").toString())) : null;
        String voiceName = (String) requestBody.get("voiceName");
        Float pitch = requestBody.get("pitch") != null ? 
                (requestBody.get("pitch") instanceof Float ? (Float) requestBody.get("pitch") : 
                 Float.parseFloat(requestBody.get("pitch").toString())) : 1.0f;
        Float speed = requestBody.get("speed") != null ? 
                (requestBody.get("speed") instanceof Float ? (Float) requestBody.get("speed") : 
                 Float.parseFloat(requestBody.get("speed").toString())) : 1.0f;

        logger.info("========== TTS调试接口调用开始 ==========");
        logger.info("请求参数 - 文本: \"{}\", TTS配置ID: {}, 语音: {}, 音调: {}, 语速: {}", 
                text, ttsId, voiceName, pitch, speed);

        try {
            // 参数验证
            if (text == null || text.trim().isEmpty()) {
                logger.error("TTS调试失败 - 文本参数为空");
                return ResultMessage.error("文本参数不能为空");
            }

            // 获取TTS服务
            SysConfig ttsConfig = null;
            TtsService ttsService;
            
            if (ttsId != null && ttsId > 0) {
                logger.debug("使用指定的TTS配置 - TTS配置ID: {}", ttsId);
                ttsConfig = configService.selectConfigById(ttsId);
                if (ttsConfig == null) {
                    logger.error("TTS调试失败 - TTS配置不存在，ID: {}", ttsId);
                    return ResultMessage.error("TTS配置不存在，ID: " + ttsId);
                }
                logger.info("TTS配置信息 - 提供商: {}, 配置名称: {}", 
                        ttsConfig.getProvider(), ttsConfig.getConfigName());
                
                // 根据TTS提供商选择合适的默认语音
                String provider = ttsConfig.getProvider();
                boolean isAliyunTts = "aliyun".equals(provider) || "aliyun-nls".equals(provider) || 
                                      "Tongyi-Qianwen".equals(provider) || 
                                      (provider != null && provider.toLowerCase().contains("aliyun"));
                
                logger.debug("TTS提供商判断 - Provider: {}, 是否为阿里云: {}", provider, isAliyunTts);
                
                if (isAliyunTts) {
                    // 阿里云TTS：如果语音名称是Edge TTS的，或者为空，使用阿里云支持的默认语音
                    if (voiceName == null || voiceName.isEmpty() || 
                        voiceName.contains("zh-CN-") || voiceName.contains("Xiaoyi") || 
                        voiceName.contains("Neural")) {
                        voiceName = "Cherry"; // 阿里云Qwen-TTS默认语音
                        logger.info("使用阿里云TTS默认语音: {} (原语音名称不兼容)", voiceName);
                    } else {
                        logger.info("使用指定的阿里云TTS语音: {}", voiceName);
                    }
                } else {
                    // Edge TTS或其他服务
                    if (voiceName == null || voiceName.isEmpty()) {
                        voiceName = "zh-CN-XiaoyiNeural"; // Edge TTS默认语音
                        logger.debug("使用Edge TTS默认语音: {}", voiceName);
                    }
                }
                
                ttsService = ttsServiceFactory.getTtsService(ttsConfig, voiceName, pitch, speed);
            } else {
                logger.info("使用默认TTS服务 (Edge TTS)");
                if (voiceName == null || voiceName.isEmpty()) {
                    voiceName = "zh-CN-XiaoyiNeural"; // Edge TTS默认语音
                }
                ttsService = ttsServiceFactory.getDefaultTtsService();
            }

            logger.info("TTS服务准备完成 - 提供商: {}, 语音: {}", 
                    ttsService.getProviderName(), voiceName);

            // 调用TTS服务
            long ttsStartTime = System.currentTimeMillis();
            logger.info("开始调用TTS服务生成音频...");
            
            String audioPath = ttsService.textToSpeech(text);
            
            long ttsDuration = System.currentTimeMillis() - ttsStartTime;
            long totalTime = System.currentTimeMillis() - startTime;

            logger.info("TTS服务调用完成 - 耗时: {}ms, 音频路径: {}", ttsDuration, audioPath);
            logger.info("========== TTS调试接口调用成功 ========== 总耗时: {}ms", totalTime);

            // 返回结果
            ResultMessage result = ResultMessage.success();
            Map<String, Object> data = new HashMap<>();
            data.put("audioPath", audioPath);
            data.put("ttsDuration", ttsDuration);
            data.put("totalTime", totalTime);
            data.put("provider", ttsService.getProviderName());
            data.put("voiceName", voiceName);
            data.put("text", text);
            data.put("textLength", text.length());
            result.put("data", data);
            
            return result;

        } catch (Exception e) {
            long totalTime = System.currentTimeMillis() - startTime;
            logger.error("========== TTS调试接口调用失败 ========== 总耗时: {}ms", totalTime, e);
            logger.error("错误详情 - 文本: \"{}\", 错误信息: {}", text, e.getMessage());
            
            ResultMessage result = ResultMessage.error("TTS生成失败: " + e.getMessage());
            Map<String, Object> errorData = new HashMap<>();
            errorData.put("error", e.getMessage());
            errorData.put("errorType", e.getClass().getSimpleName());
            errorData.put("totalTime", totalTime);
            errorData.put("text", text);
            result.put("data", errorData);
            
            return result;
        }
    }
}