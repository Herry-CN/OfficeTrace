export type AlertStatus = 'pending' | 'processing' | 'resolved'
export type AlertLevel = 'critical' | 'high' | 'medium' | 'low'

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

/** Kenya high-risk engineering camp (Garissa corridor concept) */
export const CAMP_CENTER: [number, number] = [-0.4536, 39.6461]

/** Nairobi Karen luxury villa perimeter */
export const VILLA_CENTER: [number, number] = [-1.3197, 36.7085]

export const alerts: AlertItem[] = [
  {
    id: 'ALT-20261013-88421',
    name: '营地外围人员入侵',
    type: '人员异常 / 入侵侦测',
    level: 'critical',
    status: 'pending',
    location: 'Garissa走廊·中资路桥营地东围栏',
    coords: [-0.4518, 39.6492],
    time: '2026-10-13 22:08:26',
    source: 'AI识别 · 固定摄像头 CAM-E03',
    description: '东围栏热成像检测到2名未授权人员贴近油料区，已触发空地联动预案。',
    scene: 'camp',
    thumbnails: ['thermal', 'optical'],
  },
  {
    id: 'ALT-20261013-88405',
    name: '油料区异常聚集',
    type: '油料盗窃风险',
    level: 'high',
    status: 'processing',
    location: '营地柴油罐区南侧',
    coords: [-0.4549, 39.6478],
    time: '2026-10-13 21:42:11',
    source: '机器狗 RD-02 · 近距红外',
    description: '夜间巡逻发现车辆与人员在油料区短暂停留，疑似内外勾连风险。',
    scene: 'camp',
    thumbnails: ['optical'],
  },
  {
    id: 'ALT-20261013-88390',
    name: '别墅门口黄金5分钟风险',
    type: '入户窗口期预警',
    level: 'high',
    status: 'pending',
    location: 'Nairobi Karen · 别墅门禁区',
    coords: [-1.3189, 36.7098],
    time: '2026-10-13 21:15:03',
    source: 'AI识别 · 门禁联动',
    description: '车辆抵达门口等待开门超过45秒，周边热源异常，启动静音无人机复核。',
    scene: 'villa',
    thumbnails: ['optical', 'thermal'],
  },
  {
    id: 'ALT-20261013-88372',
    name: 'VIP路线提前巡查异常',
    type: '路线安保',
    level: 'medium',
    status: 'resolved',
    location: 'Mombasa Road 临时VIP走廊',
    coords: [-1.3350, 36.8450],
    time: '2026-10-13 18:20:44',
    source: '无人机 UAV-01 · 空中侦察',
    description: '提前巡查发现路边异常停放车辆，已通知地面安保公司疏导。',
    scene: 'route',
    thumbnails: ['optical'],
  },
  {
    id: 'ALT-20261013-88351',
    name: '夜间围栏攀爬行为',
    type: '行为识别',
    level: 'medium',
    status: 'processing',
    location: '高端别墅北侧围墙',
    coords: [-1.3208, 36.7072],
    time: '2026-10-13 02:11:58',
    source: 'AI识别 · 红外慢速巡航',
    description: '静音夜航模式识别疑似攀爬动作，已联动机器狗前往近距喊话驱离。',
    scene: 'villa',
    thumbnails: ['thermal'],
  },
]

export const devices: DeviceItem[] = [
  {
    id: 'UAV-01',
    name: 'M300 RTK · 快速响应机',
    type: 'drone',
    status: 'patrol',
    battery: 78,
    location: '营地东围栏上空',
    coords: [-0.4522, 39.6485],
  },
  {
    id: 'UAV-02',
    name: 'M4TD · 别墅静音机',
    type: 'drone',
    status: 'standby',
    battery: 100,
    location: 'Karen别墅自动机巢',
    coords: [-1.3192, 36.7081],
  },
  {
    id: 'RD-01',
    name: '轮足机器狗 Alpha',
    type: 'robotDog',
    status: 'patrol',
    battery: 62,
    location: '营地主巡逻道',
    coords: [-0.4531, 39.6468],
  },
  {
    id: 'RD-02',
    name: '轮足机器狗 Bravo',
    type: 'robotDog',
    status: 'charging',
    battery: 28,
    location: '营地自动充电站 A',
    coords: [-0.4542, 39.6455],
  },
  {
    id: 'DOCK-01',
    name: '无人机自动机巢',
    type: 'dock',
    status: 'online',
    location: '营地指挥塔旁',
    coords: [-0.4538, 39.6459],
  },
  {
    id: 'CAM-E03',
    name: '东围栏热成像相机',
    type: 'camera',
    status: 'online',
    location: '东围栏制高点',
    coords: [-0.4515, 39.6495],
  },
  {
    id: 'SL-01',
    name: 'Starlink 地面中继',
    type: 'starlink',
    status: 'online',
    location: '营地通信车',
    coords: [-0.4545, 39.6462],
  },
]

export const campMission: Mission = {
  id: 'MSN-CAMP-A',
  name: 'A区 · 工程营地例行巡检',
  status: 'executing',
  scene: '高风险中资工程项目营地',
  device: 'M300 RTK',
  routeName: '营地东围栏—油料区协同航线',
  algorithm: '人员入侵 + 油料异常检测算法',
  startTime: '2026-10-13 21:55:00',
  endTime: '进行中',
  duration: '0h 18m',
  alerts: 1,
  photos: 6,
  videos: 3,
  reports: 1,
  speed: 8,
  climbSpeed: 3,
  altitude: 45,
  distance: 2.5,
  waypoints: [
    { id: 1, coords: [-0.4555, 39.6448], action: '起飞确认 / 全景拍照', gimbalPitch: -45 },
    { id: 2, coords: [-0.4540, 39.6465], action: '油料区悬停扫描', gimbalPitch: -60 },
    { id: 3, coords: [-0.4525, 39.6480], action: '东围栏热成像复核', gimbalPitch: -45 },
    { id: 4, coords: [-0.4518, 39.6492], action: '入侵点锁定跟踪', gimbalPitch: -30 },
    { id: 5, coords: [-0.4530, 39.6500], action: '外围道路侦察', gimbalPitch: -45 },
    { id: 6, coords: [-0.4548, 39.6472], action: '返航前全景取证', gimbalPitch: -50 },
  ],
  path: [
    [-0.4555, 39.6448],
    [-0.4540, 39.6465],
    [-0.4525, 39.6480],
    [-0.4518, 39.6492],
    [-0.4530, 39.6500],
    [-0.4548, 39.6472],
  ],
}

export const villaMission: Mission = {
  id: 'MSN-VILLA-N',
  name: '别墅区 · 夜间静音巡逻',
  status: 'success',
  scene: '高端别墅黄金5分钟防护',
  device: 'M4TD',
  routeName: '门禁—围墙红外慢速航线',
  algorithm: '入户窗口期风险识别',
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
  waypoints: [
    { id: 1, coords: [-1.3192, 36.7081], action: '静音起飞', gimbalPitch: -40 },
    { id: 2, coords: [-1.3189, 36.7098], action: '门禁区悬停观察', gimbalPitch: -55 },
    { id: 3, coords: [-1.3208, 36.7072], action: '北围墙红外扫描', gimbalPitch: -45 },
    { id: 4, coords: [-1.3197, 36.7085], action: '自动返巢', gimbalPitch: -30 },
  ],
  path: [
    [-1.3192, 36.7081],
    [-1.3189, 36.7098],
    [-1.3208, 36.7072],
    [-1.3197, 36.7085],
  ],
}

export const linkageSteps = [
  { step: 1, title: '摄像头发现异常', detail: 'CAM-E03 热成像触发人员贴近油料区' },
  { step: 2, title: 'AI识别确认', detail: '多源融合判定为未授权入侵，风险等级 Critical' },
  { step: 3, title: '无人机自动起飞', detail: 'UAV-01 从机巢起飞，18秒抵达目标上空' },
  { step: 4, title: '机器狗前往现场', detail: 'RD-01 近距接近，开启喊话与爆闪威慑' },
  { step: 5, title: '画面回传指挥中心', detail: '经 Starlink 地面中继回传实时图传' },
  { step: 6, title: '人员判断处置', detail: '人工确认后通知当地安保合作方介入' },
]

export const architectureLayers = [
  { layer: '第五层', name: '完整安全解决方案', capability: '面向高风险客户的一体化安防服务' },
  { layer: '第四层', name: '安全运营层', capability: '人员监控、告警处理、任务调度、应急响应' },
  { layer: '第三层', name: 'AI分析层', capability: '视频分析、异常识别、多源融合、风险判断' },
  { layer: '第二层', name: '智能感知层', capability: '摄像头、传感器、GPS、声音、红外' },
  { layer: '第一层', name: '底层设备层', capability: '机器狗、无人机、通信设备、充电站' },
]

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
