/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.h
  * @brief          : Header for main.c file.
  *                   This file contains the common defines of the application.
  ******************************************************************************
  * @attention
  *
  * <h2><center>&copy; Copyright (c) 2019 STMicroelectronics.
  * All rights reserved.</center></h2>
  *
  * This software component is licensed by ST under BSD 3-Clause license,
  * the "License"; You may not use this file except in compliance with the
  * License. You may obtain a copy of the License at:
  *                        opensource.org/licenses/BSD-3-Clause
  *
  ******************************************************************************
  */
/* USER CODE END Header */

/* Define to prevent recursive inclusion -------------------------------------*/
#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/
#include "stm32f1xx_hal.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Exported types ------------------------------------------------------------*/
/* USER CODE BEGIN ET */

/* USER CODE END ET */

/* Exported constants --------------------------------------------------------*/
/* USER CODE BEGIN EC */

/* USER CODE END EC */

/* Exported macro ------------------------------------------------------------*/
/* USER CODE BEGIN EM */

/* USER CODE END EM */

/* Exported functions prototypes ---------------------------------------------*/
void Error_Handler(void);

/* USER CODE BEGIN EFP */
void OutputMode();
void InputMode();
/* USER CODE END EFP */

/* Private defines -----------------------------------------------------------*/
#define SD_CD_Pin GPIO_PIN_14
#define SD_CD_GPIO_Port GPIOC
#define SD_WP_Pin GPIO_PIN_15
#define SD_WP_GPIO_Port GPIOC
#define SD_CS_Pin GPIO_PIN_4
#define SD_CS_GPIO_Port GPIOA
#define DB0_Pin GPIO_PIN_0
#define DB0_GPIO_Port GPIOB
#define DB1_Pin GPIO_PIN_1
#define DB1_GPIO_Port GPIOB
#define DB2_Pin GPIO_PIN_2
#define DB2_GPIO_Port GPIOB
#define phaseChange_Pin GPIO_PIN_10
#define phaseChange_GPIO_Port GPIOB
#define phaseChange_EXTI_IRQn EXTI15_10_IRQn
#define powerOn_Pin GPIO_PIN_11
#define powerOn_GPIO_Port GPIOB
#define RW_Pin GPIO_PIN_12
#define RW_GPIO_Port GPIOB
#define dataRdy_Pin GPIO_PIN_13
#define dataRdy_GPIO_Port GPIOB
#define DRVSEL_Pin GPIO_PIN_14
#define DRVSEL_GPIO_Port GPIOB
#define DEVSEL_Pin GPIO_PIN_15
#define DEVSEL_GPIO_Port GPIOB
#define Spinning_Pin GPIO_PIN_11
#define Spinning_GPIO_Port GPIOA
#define DB3_Pin GPIO_PIN_3
#define DB3_GPIO_Port GPIOB
#define DB4_Pin GPIO_PIN_4
#define DB4_GPIO_Port GPIOB
#define DB5_Pin GPIO_PIN_5
#define DB5_GPIO_Port GPIOB
#define DB6_Pin GPIO_PIN_6
#define DB6_GPIO_Port GPIOB
#define DB7_Pin GPIO_PIN_7
#define DB7_GPIO_Port GPIOB
#define phase0_Pin GPIO_PIN_8
#define phase0_GPIO_Port GPIOB
#define phase1_Pin GPIO_PIN_9
#define phase1_GPIO_Port GPIOB
/* USER CODE BEGIN Private defines */

/* USER CODE END Private defines */

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */

/************************ (C) COPYRIGHT STMicroelectronics *****END OF FILE****/
