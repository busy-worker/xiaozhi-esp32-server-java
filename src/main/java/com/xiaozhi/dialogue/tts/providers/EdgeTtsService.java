package com.xiaozhi.dialogue.tts.providers;

import io.github.whitemagic2014.tts.TTS;
import io.github.whitemagic2014.tts.TTSVoice;
import io.github.whitemagic2014.tts.bean.Voice;

import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.xiaozhi.dialogue.tts.TtsService;
import com.xiaozhi.utils.AudioUtils;

public class EdgeTtsService implements TtsService {
    private static final Logger logger = LoggerFactory.getLogger(EdgeTtsService.class);

    private static final String PROVIDER_NAME = "edge";

    // 音频名称
    private String voiceName;

    // 音频输出路径
    private String outputPath;
    
    // 语音音调 (0.5-2.0)
    private Float pitch;
    
    // 语音语速 (0.5-2.0)
    private Float speed;

    public EdgeTtsService(String voiceName, Float pitch, Float speed, String outputPath) {
        this.voiceName = voiceName;
        this.pitch = pitch;
        this.speed = speed;
        this.outputPath = outputPath;
    }

    @Override
    public String getProviderName() {
        return PROVIDER_NAME;
    }

    @Override
    public String audioFormat() {
        return "mp3";
    }

    @Override
    public String textToSpeech(String text) throws Exception {
        long startTime = System.currentTimeMillis();
        logger.info("Edge TTS开始生成 - 文本长度: {}, 语音: {}, 音调: {}, 语速: {}", 
                text.length(), voiceName, pitch, speed);
        
        try {
            // 获取中文语音
            long step1Start = System.currentTimeMillis();
            Voice voiceObj = TTSVoice.provides().stream()
                    .filter(v -> v.getShortName().equals(voiceName))
                    .collect(Collectors.toList()).get(0);
            long step1Time = System.currentTimeMillis() - step1Start;
            logger.debug("Edge TTS步骤1 - 获取语音对象完成，耗时: {}ms", step1Time);

            long step2Start = System.currentTimeMillis();
            TTS ttsEngine = new TTS(voiceObj, text);
            long step2Time = System.currentTimeMillis() - step2Start;
            logger.debug("Edge TTS步骤2 - 创建TTS引擎完成，耗时: {}ms", step2Time);
            
            // 计算Edge TTS的rate参数 (将0.5-2.0映射到-50%到+100%)
            // speed=0.5 -> rate=-50%, speed=1.0 -> rate=+0%, speed=2.0 -> rate=+100%
            int ratePercent = (int)((speed - 1.0f) * 100);
            
            // 计算Edge TTS的pitch参数 (将0.5-2.0映射到-50Hz到+50Hz)
            // pitch=0.5 -> -50Hz, pitch=1.0 -> 0Hz, pitch=2.0 -> +50Hz
            int pitchHz = (int)((pitch - 1.0f) * 50);
            
            logger.debug("Edge TTS参数 - rate: {}%, pitch: {}Hz", ratePercent, pitchHz);
            
            // 执行TTS转换获取音频文件（这是最耗时的步骤）
            long step3Start = System.currentTimeMillis();
            logger.info("Edge TTS步骤3 - 开始调用Edge TTS API，文本: \"{}\"", text);
            
            String audioFilePath = ttsEngine.findHeadHook()
                    .storage(outputPath)
                    .fileName(getAudioFileName().split("\\.")[0])
                    .isRateLimited(true)
                    .overwrite(false)
                    .voicePitch(pitchHz + "Hz")
                    .voiceRate(ratePercent + "%")
                    .formatMp3()
                    .trans();
            
            long step3Time = System.currentTimeMillis() - step3Start;
            logger.info("Edge TTS步骤3 - API调用完成，耗时: {}ms，返回文件: {}", step3Time, audioFilePath);

            String fullPath = outputPath + audioFilePath;
            
            // 检查文件是否存在
            if (!Files.exists(Paths.get(fullPath))) {
                logger.error("Edge TTS错误 - 音频文件不存在: {}", fullPath);
                throw new Exception("Edge TTS生成的音频文件不存在: " + fullPath);
            }
            
            long fileSize = Files.size(Paths.get(fullPath));
            logger.debug("Edge TTS - 生成的MP3文件大小: {} bytes", fileSize);

            // 1. 将MP3转换为PCM (已经设置为16kHz采样率和单声道)
            long step4Start = System.currentTimeMillis();
            logger.debug("Edge TTS步骤4 - 开始MP3转PCM转换");
            byte[] pcmData = AudioUtils.mp3ToPcm(fullPath);
            long step4Time = System.currentTimeMillis() - step4Start;
            logger.debug("Edge TTS步骤4 - MP3转PCM完成，耗时: {}ms，PCM数据大小: {} bytes", 
                    step4Time, pcmData != null ? pcmData.length : 0);

            // 2. 将PCM转换回WAV (使用AudioUtils中的设置：16kHz, 单声道, 160kbps)
            long step5Start = System.currentTimeMillis();
            logger.debug("Edge TTS步骤5 - 开始PCM转WAV转换");
            String resampledFileName = AudioUtils.saveAsWav(pcmData);
            long step5Time = System.currentTimeMillis() - step5Start;
            logger.debug("Edge TTS步骤5 - PCM转WAV完成，耗时: {}ms，文件名: {}", 
                    step5Time, resampledFileName);

            // 3. 删除原始文件
            long step6Start = System.currentTimeMillis();
            Files.deleteIfExists(Paths.get(fullPath));
            long step6Time = System.currentTimeMillis() - step6Start;
            logger.debug("Edge TTS步骤6 - 删除原始MP3文件完成，耗时: {}ms", step6Time);

            // 4. 返回重采样后的文件路径
            String resultPath = AudioUtils.AUDIO_PATH + resampledFileName;
            long totalTime = System.currentTimeMillis() - startTime;
            logger.info("Edge TTS生成成功 - 总耗时: {}ms，最终文件: {}", totalTime, resultPath);
            
            return resultPath;
            
        } catch (Exception e) {
            long totalTime = System.currentTimeMillis() - startTime;
            logger.error("Edge TTS生成失败 - 总耗时: {}ms，文本: \"{}\"，错误: {}", 
                    totalTime, text, e.getMessage(), e);
            throw e;
        }
    }

}