import type { Locale } from '../i18n/types'
import { uiMessages } from '../i18n/ui'

export type AlertStatus = 'pending' | 'processing' | 'resolved'
export type AlertLevel = 'critical' | 'high' | 'medium' | 'low'
export type SiteTag = 'camp' | 'villa' | 'both'

export interface AlertItem {
  id: string
  name: string
  type: string
  level: AlertLevel
  status: AlertStatus
  location: string
  coords: [number, number]
  time: string
  source: string
  description: string
  scene: 'camp' | 'villa' | 'route'
  thumbnails: string[]
}

export interface DeviceItem {
  id: string
  name: string
  type: 'drone' | 'robotDog' | 'camera' | 'dock' | 'starlink'
  status: 'online' | 'patrol' | 'charging' | 'offline' | 'standby'
  battery?: number
  location: string
  coords: [number, number]
  site: SiteTag
}

export interface Waypoint {
  id: number
  coords: [number, number]
  action: string
  gimbalPitch: number
}

export interface Mission {
  id: string
  name: string
  status: 'executing' | 'success' | 'pending'
  scene: string
  device: string
  routeName: string
  algorithm: string
  startTime: string
  endTime: string
  duration: string
  alerts: number
  photos: number
  videos: number
  reports: number
  speed: number
  climbSpeed: number
  altitude: number
  distance: number
  waypoints: Waypoint[]
  path: [number, number][]
}

export interface LinkageStep {
  step: number
  title: string
  detail: string
}

export interface ArchitectureLayer {
  layer: string
  name: string
  capability: string
}

/** Kenya high-risk engineering camp (Garissa corridor concept) */
export const CAMP_CENTER: [number, number] = [-0.4536, 39.6461]

/** Nairobi Karen luxury villa perimeter */
export const VILLA_CENTER: [number, number] = [-1.3197, 36.7085]

type L10n<T> = Record<Locale, T>

const alertBase = [
  {
    id: 'ALT-20261013-88421',
    level: 'critical' as const,
    status: 'pending' as const,
    coords: [-0.4518, 39.6492] as [number, number],
    time: '2026-10-13 22:08:26',
    scene: 'camp' as const,
    thumbnails: ['thermal', 'optical'],
  },
  {
    id: 'ALT-20261013-88405',
    level: 'high' as const,
    status: 'processing' as const,
    coords: [-0.4549, 39.6478] as [number, number],
    time: '2026-10-13 21:42:11',
    scene: 'camp' as const,
    thumbnails: ['optical'],
  },
  {
    id: 'ALT-20261013-88390',
    level: 'high' as const,
    status: 'pending' as const,
    coords: [-1.3189, 36.7098] as [number, number],
    time: '2026-10-13 21:15:03',
    scene: 'villa' as const,
    thumbnails: ['optical', 'thermal'],
  },
  {
    id: 'ALT-20261013-88372',
    level: 'medium' as const,
    status: 'resolved' as const,
    coords: [-1.335, 36.845] as [number, number],
    time: '2026-10-13 18:20:44',
    scene: 'route' as const,
    thumbnails: ['optical'],
  },
  {
    id: 'ALT-20261013-88351',
    level: 'medium' as const,
    status: 'processing' as const,
    coords: [-1.3208, 36.7072] as [number, number],
    time: '2026-10-13 02:11:58',
    scene: 'villa' as const,
    thumbnails: ['thermal'],
  },
]

const alertText: L10n<
  Record<string, Pick<AlertItem, 'name' | 'type' | 'location' | 'source' | 'description'>>
> = {
  zh: {
    'ALT-20261013-88421': {
      name: '营地外围人员入侵',
      type: '人员异常 / 入侵侦测',
      location: 'Garissa走廊·中资路桥营地东围栏',
      source: 'AI识别 · 固定摄像头 CAM-E03',
      description: '东围栏热成像检测到2名未授权人员贴近油料区，已触发空地联动预案。',
    },
    'ALT-20261013-88405': {
      name: '油料区异常聚集',
      type: '油料盗窃风险',
      location: '营地柴油罐区南侧',
      source: '机器狗 RD-02 · 近距红外',
      description: '夜间巡逻发现车辆与人员在油料区短暂停留，疑似内外勾连风险。',
    },
    'ALT-20261013-88390': {
      name: '别墅门口黄金5分钟风险',
      type: '入户窗口期预警',
      location: 'Nairobi Karen · 别墅门禁区',
      source: 'AI识别 · 门禁联动',
      description: '车辆抵达门口等待开门超过45秒，周边热源异常，启动静音无人机复核。',
    },
    'ALT-20261013-88372': {
      name: 'VIP路线提前巡查异常',
      type: '路线安保',
      location: 'Mombasa Road 临时VIP走廊',
      source: '无人机 UAV-01 · 空中侦察',
      description: '提前巡查发现路边异常停放车辆，已通知地面安保公司疏导。',
    },
    'ALT-20261013-88351': {
      name: '夜间围栏攀爬行为',
      type: '行为识别',
      location: '高端别墅北侧围墙',
      source: 'AI识别 · 红外慢速巡航',
      description: '静音夜航模式识别疑似攀爬动作，已联动机器狗前往近距喊话驱离。',
    },
  },
  en: {
    'ALT-20261013-88421': {
      name: 'Camp Perimeter Intrusion',
      type: 'Personnel Anomaly / Intrusion',
      location: 'Garissa corridor · East fence of Chinese road camp',
      source: 'AI detection · Fixed camera CAM-E03',
      description:
        'Thermal imaging detected 2 unauthorized persons approaching the fuel zone. Air-ground response playbook triggered.',
    },
    'ALT-20261013-88405': {
      name: 'Abnormal Gathering at Fuel Depot',
      type: 'Fuel Theft Risk',
      location: 'South side of camp diesel tanks',
      source: 'Robot dog RD-02 · Close-range IR',
      description:
        'Night patrol found a vehicle and people briefly stopping at the fuel area — possible insider collusion risk.',
    },
    'ALT-20261013-88390': {
      name: 'Villa Gate Golden-5-Minute Risk',
      type: 'Entry Window Alert',
      location: 'Nairobi Karen · Villa gate zone',
      source: 'AI detection · Gate linkage',
      description:
        'Vehicle waited at the gate for over 45 seconds with abnormal nearby heat signatures. Silent drone review launched.',
    },
    'ALT-20261013-88372': {
      name: 'VIP Route Pre-Check Anomaly',
      type: 'Route Security',
      location: 'Mombasa Road temporary VIP corridor',
      source: 'Drone UAV-01 · Aerial recon',
      description:
        'Pre-check found an abnormally parked roadside vehicle. Local security partner notified for clearance.',
    },
    'ALT-20261013-88351': {
      name: 'Night Fence Climbing Behavior',
      type: 'Behavior Recognition',
      location: 'North wall of luxury villa',
      source: 'AI detection · IR slow cruise',
      description:
        'Silent night mode detected possible climbing. Robot dog dispatched for close-range voice deterrence.',
    },
  },
}

const deviceBase = [
  {
    id: 'UAV-01',
    type: 'drone' as const,
    status: 'patrol' as const,
    battery: 78,
    coords: [-0.4522, 39.6485] as [number, number],
    site: 'camp' as const,
  },
  {
    id: 'UAV-02',
    type: 'drone' as const,
    status: 'standby' as const,
    battery: 100,
    coords: [-1.3192, 36.7081] as [number, number],
    site: 'villa' as const,
  },
  {
    id: 'RD-01',
    type: 'robotDog' as const,
    status: 'patrol' as const,
    battery: 62,
    coords: [-0.4531, 39.6468] as [number, number],
    site: 'camp' as const,
  },
  {
    id: 'RD-02',
    type: 'robotDog' as const,
    status: 'charging' as const,
    battery: 28,
    coords: [-0.4542, 39.6455] as [number, number],
    site: 'camp' as const,
  },
  {
    id: 'DOCK-01',
    type: 'dock' as const,
    status: 'online' as const,
    coords: [-0.4538, 39.6459] as [number, number],
    site: 'camp' as const,
  },
  {
    id: 'CAM-E03',
    type: 'camera' as const,
    status: 'online' as const,
    coords: [-0.4515, 39.6495] as [number, number],
    site: 'both' as const,
  },
  {
    id: 'SL-01',
    type: 'starlink' as const,
    status: 'online' as const,
    coords: [-0.4545, 39.6462] as [number, number],
    site: 'camp' as const,
  },
]

const deviceText: L10n<Record<string, Pick<DeviceItem, 'name' | 'location'>>> = {
  zh: {
    'UAV-01': { name: 'M300 RTK · 快速响应机', location: '营地东围栏上空' },
    'UAV-02': { name: 'M4TD · 别墅静音机', location: 'Karen别墅自动机巢' },
    'RD-01': { name: '轮足机器狗 Alpha', location: '营地主巡逻道' },
    'RD-02': { name: '轮足机器狗 Bravo', location: '营地自动充电站 A' },
    'DOCK-01': { name: '无人机自动机巢', location: '营地指挥塔旁' },
    'CAM-E03': { name: '东围栏热成像相机', location: '东围栏制高点' },
    'SL-01': { name: 'Starlink 地面中继', location: '营地通信车' },
  },
  en: {
    'UAV-01': { name: 'M300 RTK · Rapid Response', location: 'Above east camp fence' },
    'UAV-02': { name: 'M4TD · Silent Villa Unit', location: 'Karen villa auto dock' },
    'RD-01': { name: 'Wheeled Robot Dog Alpha', location: 'Main camp patrol road' },
    'RD-02': { name: 'Wheeled Robot Dog Bravo', location: 'Camp auto charger A' },
    'DOCK-01': { name: 'Drone Auto Dock', location: 'Beside camp command tower' },
    'CAM-E03': { name: 'East Fence Thermal Camera', location: 'East fence high point' },
    'SL-01': { name: 'Starlink Ground Relay', location: 'Camp comms vehicle' },
  },
}

const campPath: [number, number][] = [
  [-0.4555, 39.6448],
  [-0.454, 39.6465],
  [-0.4525, 39.648],
  [-0.4518, 39.6492],
  [-0.453, 39.65],
  [-0.4548, 39.6472],
]

const villaPath: [number, number][] = [
  [-1.3192, 36.7081],
  [-1.3189, 36.7098],
  [-1.3208, 36.7072],
  [-1.3197, 36.7085],
]

const campMissionText: L10n<{
  name: string
  scene: string
  routeName: string
  algorithm: string
  endTime: string
  waypoints: string[]
}> = {
  zh: {
    name: 'A区 · 工程营地例行巡检',
    scene: '高风险中资工程项目营地',
    routeName: '营地东围栏—油料区协同航线',
    algorithm: '人员入侵 + 油料异常检测算法',
    endTime: '进行中',
    waypoints: [
      '起飞确认 / 全景拍照',
      '油料区悬停扫描',
      '东围栏热成像复核',
      '入侵点锁定跟踪',
      '外围道路侦察',
      '返航前全景取证',
    ],
  },
  en: {
    name: 'Zone A · Engineering Camp Routine Patrol',
    scene: 'High-risk Chinese engineering project camp',
    routeName: 'East fence — fuel zone coordinated route',
    algorithm: 'Intrusion + fuel anomaly detection',
    endTime: 'In progress',
    waypoints: [
      'Takeoff confirm / panorama',
      'Hover scan over fuel zone',
      'East fence thermal review',
      'Lock and track intrusion point',
      'Outer road reconnaissance',
      'Panorama evidence before RTH',
    ],
  },
}

const villaMissionText: L10n<{
  name: string
  scene: string
  routeName: string
  algorithm: string
  waypoints: string[]
}> = {
  zh: {
    name: '别墅区 · 夜间静音巡逻',
    scene: '高端别墅黄金5分钟防护',
    routeName: '门禁—围墙红外慢速航线',
    algorithm: '入户窗口期风险识别',
    waypoints: ['静音起飞', '门禁区悬停观察', '北围墙红外扫描', '自动返巢'],
  },
  en: {
    name: 'Villa Zone · Night Silent Patrol',
    scene: 'Luxury villa golden-5-minute protection',
    routeName: 'Gate — wall IR slow cruise',
    algorithm: 'Entry-window risk recognition',
    waypoints: ['Silent takeoff', 'Hover observe at gate', 'North wall IR scan', 'Auto return to dock'],
  },
}

const linkageText: L10n<Omit<LinkageStep, 'step'>[]> = {
  zh: [
    { title: '摄像头发现异常', detail: 'CAM-E03 热成像触发人员贴近油料区' },
    { title: 'AI识别确认', detail: '多源融合判定为未授权入侵，风险等级 Critical' },
    { title: '无人机自动起飞', detail: 'UAV-01 从机巢起飞，18秒抵达目标上空' },
    { title: '机器狗前往现场', detail: 'RD-01 近距接近，开启喊话与爆闪威慑' },
    { title: '画面回传指挥中心', detail: '经 Starlink 地面中继回传实时图传' },
    { title: '人员判断处置', detail: '人工确认后通知当地安保合作方介入' },
  ],
  en: [
    { title: 'Camera Detects Anomaly', detail: 'CAM-E03 thermal triggers person near fuel zone' },
    { title: 'AI Confirms', detail: 'Multi-source fusion classifies unauthorized intrusion as Critical' },
    { title: 'Drone Auto Takeoff', detail: 'UAV-01 launches from dock and reaches target in 18s' },
    { title: 'Robot Dog Responds', detail: 'RD-01 approaches and enables voice + strobe deterrence' },
    { title: 'Video to Command Center', detail: 'Live feed uplinked via Starlink ground relay' },
    { title: 'Human Disposition', detail: 'After human confirm, local security partner is engaged' },
  ],
}

const architectureText: L10n<ArchitectureLayer[]> = {
  zh: [
    { layer: '第五层', name: '完整安全解决方案', capability: '面向高风险客户的一体化安防服务' },
    { layer: '第四层', name: '安全运营层', capability: '人员监控、告警处理、任务调度、应急响应' },
    { layer: '第三层', name: 'AI分析层', capability: '视频分析、异常识别、多源融合、风险判断' },
    { layer: '第二层', name: '智能感知层', capability: '摄像头、传感器、GPS、声音、红外' },
    { layer: '第一层', name: '底层设备层', capability: '机器狗、无人机、通信设备、充电站' },
  ],
  en: [
    { layer: 'Layer 5', name: 'Complete Security Solution', capability: 'Integrated security service for high-risk clients' },
    { layer: 'Layer 4', name: 'Security Operations', capability: 'Monitoring, alert handling, task dispatch, emergency response' },
    { layer: 'Layer 3', name: 'AI Analytics', capability: 'Video analytics, anomaly detection, fusion, risk judgment' },
    { layer: 'Layer 2', name: 'Smart Sensing', capability: 'Cameras, sensors, GPS, audio, infrared' },
    { layer: 'Layer 1', name: 'Device Layer', capability: 'Robot dogs, drones, comms gear, charging docks' },
  ],
}

export const kpiStats = {
  dronesOnline: 2,
  dogsOnline: 2,
  docksOnline: 1,
  camerasOnline: 12,
  todayFlights: 7,
  todayMileage: 18.6,
  todayFlightMin: 142,
  pendingTasks: 3,
  doneTasks: 5,
  pendingAlerts: 2,
  processingAlerts: 2,
  resolvedAlerts: 1,
}

export function getAlerts(locale: Locale): AlertItem[] {
  return alertBase.map((base) => ({
    ...base,
    ...alertText[locale][base.id],
  }))
}

export function getDevices(locale: Locale): DeviceItem[] {
  return deviceBase.map((base) => ({
    ...base,
    ...deviceText[locale][base.id],
  }))
}

export function getCampMission(locale: Locale): Mission {
  const text = campMissionText[locale]
  return {
    id: 'MSN-CAMP-A',
    name: text.name,
    status: 'executing',
    scene: text.scene,
    device: 'M300 RTK',
    routeName: text.routeName,
    algorithm: text.algorithm,
    startTime: '2026-10-13 21:55:00',
    endTime: text.endTime,
    duration: '0h 18m',
    alerts: 1,
    photos: 6,
    videos: 3,
    reports: 1,
    speed: 8,
    climbSpeed: 3,
    altitude: 45,
    distance: 2.5,
    waypoints: campPath.map((coords, i) => ({
      id: i + 1,
      coords,
      action: text.waypoints[i],
      gimbalPitch: [-45, -60, -45, -30, -45, -50][i],
    })),
    path: campPath,
  }
}

export function getVillaMission(locale: Locale): Mission {
  const text = villaMissionText[locale]
  return {
    id: 'MSN-VILLA-N',
    name: text.name,
    status: 'success',
    scene: text.scene,
    device: 'M4TD',
    routeName: text.routeName,
    algorithm: text.algorithm,
    startTime: '2026-10-13 22:00:00',
    endTime: '2026-10-13 22:35:00',
    duration: '0h 35m',
    alerts: 1,
    photos: 4,
    videos: 2,
    reports: 1,
    speed: 4,
    climbSpeed: 2,
    altitude: 35,
    distance: 1.2,
    waypoints: villaPath.map((coords, i) => ({
      id: i + 1,
      coords,
      action: text.waypoints[i],
      gimbalPitch: [-40, -55, -45, -30][i],
    })),
    path: villaPath,
  }
}

export function getLinkageSteps(locale: Locale): LinkageStep[] {
  return linkageText[locale].map((item, index) => ({ step: index + 1, ...item }))
}

export function getArchitectureLayers(locale: Locale): ArchitectureLayer[] {
  return architectureText[locale]
}

export function getDeviceTypeLabel(locale: Locale, type: DeviceItem['type']) {
  const ui = uiMessages[locale]
  const map: Record<DeviceItem['type'], string> = {
    drone: ui.mapDrone,
    robotDog: ui.mapDog,
    camera: ui.mapSensor,
    dock: locale === 'zh' ? '机巢' : 'Dock',
    starlink: locale === 'zh' ? '中继' : 'Relay',
  }
  return map[type]
}

/** Default Chinese exports for tests / legacy imports */
export const alerts = getAlerts('zh')
export const devices = getDevices('zh')
export const campMission = getCampMission('zh')
export const villaMission = getVillaMission('zh')
export const linkageSteps = getLinkageSteps('zh')
export const architectureLayers = getArchitectureLayers('zh')
