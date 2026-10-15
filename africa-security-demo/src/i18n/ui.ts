import type { Locale } from './types'

export type UiMessages = {
  title: string
  subtitle: string
  kenyaOps: string
  sceneSwitch: string
  sceneCamp: string
  sceneVilla: string
  userRole: string
  langSwitch: string
  alertDetails: string
  aiFusion: string
  dronesOnline: string
  robotDogs: string
  sensors: string
  pending: string
  thermal: string
  optical: string
  alertId: string
  alertType: string
  location: string
  coords: string
  alertTime: string
  alertSource: string
  handleStatus: string
  statusPending: string
  statusProcessing: string
  statusResolved: string
  statusExecuting: string
  statusSuccess: string
  statusOnline: string
  statusPatrol: string
  statusCharging: string
  statusOffline: string
  statusStandby: string
  tabMap: string
  tabAlerts: string
  tabDevices: string
  tabLinkage: string
  tabFlight: string
  tabArchitecture: string
  alertEvents: string
  photos: string
  videos: string
  flightReports: string
  metaScene: string
  metaDevice: string
  metaRoute: string
  metaAlgorithm: string
  metaDuration: string
  metaWindow: string
  filterAll: string
  todayFlights: string
  flightMileage: string
  flightMinutes: string
  docksOnline: string
  deviceId: string
  deviceLocation: string
  linkageTitle: string
  currentPlan: string
  humanConfirm: string
  linkageIntro: string
  triggerEvent: string
  airUnit: string
  groundUnit: string
  comms: string
  disposition: string
  triggerEventValue: string
  airUnitValue: string
  groundUnitValue: string
  commsValue: string
  dispositionValue: string
  principleCore: string
  architectureTitle: string
  architecturePoc: string
  todayTasks: string
  tasksPendingDone: string
  immediate: string
  scheduled: string
  cyclic: string
  routeInfo: string
  routeName: string
  flightSpeed: string
  climbSpeed: string
  flightAltitude: string
  routeDistance: string
  waypointCount: string
  waypointInfo: string
  gimbalPitch: string
  waypointAction: string
  todayAlarms: string
  navOps: string
  navAlerts: string
  navAirGround: string
  navAssets: string
  navSolution: string
  mainModules: string
  mapRoute: string
  mapDrone: string
  mapDog: string
  mapSensor: string
  mapAlert: string
  waypoint: string
  inProgress: string
  viewDesktop: string
  viewMobile: string
  mobileHome: string
  mobileAlerts: string
  mobileLive: string
  mobileDevices: string
  mobileMore: string
  mobileGreeting: string
  mobileOpsSummary: string
  mobileOpenLive: string
  mobileLiveTitle: string
  mobileSelectFeed: string
  mobileFeedDrone: string
  mobileFeedDog: string
  mobileLiveBadge: string
  mobileLatency: string
  mobileSignal: string
  mobileBattery: string
  mobileAltitude: string
  mobileSpeed: string
  mobileOptical: string
  mobileThermal: string
  mobileSplit: string
  mobileIntercom: string
  mobileChannel: string
  mobilePtt: string
  mobilePttHint: string
  mobileTalking: string
  mobileListening: string
  mobileMute: string
  mobileUnmute: string
  mobileSpeakerOn: string
  mobileChatEmpty: string
  mobileYou: string
  mobileDeviceSaid: string
  mobileSiren: string
  mobileSpotlight: string
  mobileSnapshot: string
  mobileReturn: string
  mobilePendingAlerts: string
  mobileActiveUnits: string
  mobileQuickActions: string
  mobileActionDeterrence: string
  mobileActionDispatch: string
  mobileDemoNote: string
}

const zh: UiMessages = {
  title: '非洲安防空地一体综合管理平台',
  subtitle: 'Africa Air-Ground Integrated Security Platform',
  kenyaOps: 'Kenya Ops',
  sceneSwitch: '场景切换',
  sceneCamp: '工程营地',
  sceneVilla: '高端别墅',
  userRole: 'admin · 安全运营',
  langSwitch: '语言',
  alertDetails: '预警详情',
  aiFusion: 'AI + 多源融合',
  dronesOnline: '无人机在线',
  robotDogs: '机器狗',
  sensors: '感知点位',
  pending: '待处理',
  thermal: '热成像',
  optical: '光学取证',
  alertId: '预警编号',
  alertType: '违法类型',
  location: '地点',
  coords: '坐标',
  alertTime: '报警时间',
  alertSource: '报警来源',
  handleStatus: '处理状态',
  statusPending: '待处理',
  statusProcessing: '处理中',
  statusResolved: '已处理',
  statusExecuting: '执行中',
  statusSuccess: '执行成功',
  statusOnline: '在线',
  statusPatrol: '巡逻中',
  statusCharging: '充电中',
  statusOffline: '离线',
  statusStandby: '待命',
  tabMap: '地图',
  tabAlerts: '预警线索',
  tabDevices: '设备',
  tabLinkage: '空地联动',
  tabFlight: '飞行成果',
  tabArchitecture: '五层架构',
  alertEvents: '预警事件',
  photos: '拍摄照片',
  videos: '拍摄视频',
  flightReports: '飞行报告',
  metaScene: '场景',
  metaDevice: '设备',
  metaRoute: '航线',
  metaAlgorithm: '算法',
  metaDuration: '时长',
  metaWindow: '时段',
  filterAll: '全部',
  todayFlights: '今日飞行次数',
  flightMileage: '飞行里程 km',
  flightMinutes: '飞行时长 min',
  docksOnline: '机巢在线',
  deviceId: '编号',
  deviceLocation: '位置',
  linkageTitle: '系统联动闭环（摄像头 → AI → 无人机 → 机器狗 → 指挥中心）',
  currentPlan: '当前预案',
  humanConfirm: '人工最终确认',
  linkageIntro:
    '真正的产品价值来自设备联动：无人机负责空中大范围，机器狗负责地面近距离；声光驱离（爆闪+喊话+警报）作为第一响应，不做武器化自动攻击。',
  triggerEvent: '触发事件',
  airUnit: '空中单元',
  groundUnit: '地面单元',
  comms: '通信保障',
  disposition: '处置原则',
  triggerEventValue: '营地外围人员入侵',
  airUnitValue: 'UAV-01 快速起飞侦察',
  groundUnitValue: 'RD-01 近距接近驱离',
  commsValue: 'Starlink 地面中继回传',
  dispositionValue: '人在回路，最终处置权在人',
  principleCore:
    '核心定位：不是“机器狗销售”，而是面向高风险客户的智能安防解决方案 — 设备 + AI + 通信 + 人员 + 情报 的系统联动。',
  architectureTitle: '五层架构 · 安全能力提供商',
  architecturePoc:
    'POC优先场景：高风险工程营地限定区域智能巡逻，或高端别墅夜间外围巡逻。用最小成本验证“客户→痛点→方案→报价→付款→交付→反馈”闭环。',
  todayTasks: '今日任务',
  tasksPendingDone: '待执行 {pending} / 已执行 {done}',
  immediate: '立即执行',
  scheduled: '定时模式',
  cyclic: '循环模式',
  routeInfo: '航线信息',
  routeName: '航线名称',
  flightSpeed: '飞行速度',
  climbSpeed: '上升速度',
  flightAltitude: '飞行高度',
  routeDistance: '航线里程',
  waypointCount: '航点数量',
  waypointInfo: '航点信息',
  gimbalPitch: '云台俯仰',
  waypointAction: '航点动作',
  todayAlarms: '今日告警',
  navOps: '综合态势',
  navAlerts: '预警中心',
  navAirGround: '空地协同',
  navAssets: '资产设备',
  navSolution: '方案能力',
  mainModules: '主模块',
  mapRoute: '航线',
  mapDrone: '无人机',
  mapDog: '机器狗',
  mapSensor: '感知设备',
  mapAlert: '预警点',
  waypoint: '航点',
  inProgress: '进行中',
  viewDesktop: '指挥舱',
  viewMobile: '手机端',
  mobileHome: '首页',
  mobileAlerts: '告警',
  mobileLive: '实时',
  mobileDevices: '设备',
  mobileMore: '我的',
  mobileGreeting: '现场安防助手',
  mobileOpsSummary: '空地一体 · 肯尼亚运营',
  mobileOpenLive: '进入实时画面',
  mobileLiveTitle: '实时画面与对讲',
  mobileSelectFeed: '选择画面源',
  mobileFeedDrone: '无人机',
  mobileFeedDog: '机器狗',
  mobileLiveBadge: 'LIVE',
  mobileLatency: '时延',
  mobileSignal: '信号',
  mobileBattery: '电量',
  mobileAltitude: '高度',
  mobileSpeed: '速度',
  mobileOptical: '光学',
  mobileThermal: '热成像',
  mobileSplit: '分屏',
  mobileIntercom: '对讲频道',
  mobileChannel: '当前频道',
  mobilePtt: '按住说话',
  mobilePttHint: '松开结束 · 经 Starlink 中继回传',
  mobileTalking: '正在讲话…',
  mobileListening: '监听中',
  mobileMute: '静音',
  mobileUnmute: '取消静音',
  mobileSpeakerOn: '扬声器开',
  mobileChatEmpty: '暂无对讲记录，按住下方按钮开始喊话。',
  mobileYou: '我',
  mobileDeviceSaid: '设备回传',
  mobileSiren: '警报',
  mobileSpotlight: '爆闪',
  mobileSnapshot: '截图',
  mobileReturn: '返航/回充',
  mobilePendingAlerts: '待处理告警',
  mobileActiveUnits: '在线单元',
  mobileQuickActions: '快捷动作',
  mobileActionDeterrence: '声光驱离',
  mobileActionDispatch: '调派最近单元',
  mobileDemoNote: '演示画面为模拟实时流，对讲为本地交互模拟。',
}

const en: UiMessages = {
  title: 'Africa Air-Ground Integrated Security Platform',
  subtitle: '非洲安防空地一体综合管理平台',
  kenyaOps: 'Kenya Ops',
  sceneSwitch: 'Scene switch',
  sceneCamp: 'Engineering Camp',
  sceneVilla: 'Luxury Villa',
  userRole: 'admin · Security Ops',
  langSwitch: 'Language',
  alertDetails: 'Alert Details',
  aiFusion: 'AI + Multi-source Fusion',
  dronesOnline: 'Drones Online',
  robotDogs: 'Robot Dogs',
  sensors: 'Sensors',
  pending: 'Pending',
  thermal: 'Thermal',
  optical: 'Optical Evidence',
  alertId: 'Alert ID',
  alertType: 'Alert Type',
  location: 'Location',
  coords: 'Coordinates',
  alertTime: 'Alert Time',
  alertSource: 'Source',
  handleStatus: 'Status',
  statusPending: 'Pending',
  statusProcessing: 'In Progress',
  statusResolved: 'Resolved',
  statusExecuting: 'Executing',
  statusSuccess: 'Completed',
  statusOnline: 'Online',
  statusPatrol: 'On Patrol',
  statusCharging: 'Charging',
  statusOffline: 'Offline',
  statusStandby: 'Standby',
  tabMap: 'Map',
  tabAlerts: 'Alert Leads',
  tabDevices: 'Devices',
  tabLinkage: 'Air-Ground Link',
  tabFlight: 'Flight Results',
  tabArchitecture: '5-Layer Stack',
  alertEvents: 'Alert Events',
  photos: 'Photos',
  videos: 'Videos',
  flightReports: 'Flight Reports',
  metaScene: 'Scene',
  metaDevice: 'Device',
  metaRoute: 'Route',
  metaAlgorithm: 'Algorithm',
  metaDuration: 'Duration',
  metaWindow: 'Window',
  filterAll: 'All',
  todayFlights: 'Flights Today',
  flightMileage: 'Mileage km',
  flightMinutes: 'Flight min',
  docksOnline: 'Docks Online',
  deviceId: 'ID',
  deviceLocation: 'Location',
  linkageTitle: 'Linkage Loop (Camera → AI → Drone → Robot Dog → Command Center)',
  currentPlan: 'Active Playbook',
  humanConfirm: 'Human Final Confirm',
  linkageIntro:
    'Real value comes from system linkage: drones cover wide-area air reconnaissance while robot dogs handle close-range ground response. Acoustic-light deterrence is the first response — no automated weaponized attack.',
  triggerEvent: 'Trigger',
  airUnit: 'Air Unit',
  groundUnit: 'Ground Unit',
  comms: 'Comms',
  disposition: 'Disposition',
  triggerEventValue: 'Perimeter intrusion near fuel zone',
  airUnitValue: 'UAV-01 rapid takeoff recon',
  groundUnitValue: 'RD-01 close approach deterrence',
  commsValue: 'Starlink ground relay uplink',
  dispositionValue: 'Human-in-the-loop; final action by people',
  principleCore:
    'Core positioning: not “selling robot dogs”, but an intelligent security capability for high-risk clients — Device + AI + Comms + People + Intelligence.',
  architectureTitle: 'Five-Layer Stack · Security Capability Provider',
  architecturePoc:
    'POC priority: confined smart patrol at high-risk engineering camps, or night perimeter patrol for luxury villas. Validate the loop Customer → Pain → Solution → Quote → Payment → Delivery → Feedback at minimal cost.',
  todayTasks: "Today's Tasks",
  tasksPendingDone: 'Pending {pending} / Done {done}',
  immediate: 'Immediate',
  scheduled: 'Scheduled',
  cyclic: 'Cyclic',
  routeInfo: 'Route Info',
  routeName: 'Route Name',
  flightSpeed: 'Cruise Speed',
  climbSpeed: 'Climb Speed',
  flightAltitude: 'Altitude',
  routeDistance: 'Distance',
  waypointCount: 'Waypoints',
  waypointInfo: 'Waypoint Info',
  gimbalPitch: 'Gimbal Pitch',
  waypointAction: 'Action',
  todayAlarms: "Today's Alerts",
  navOps: 'Ops Overview',
  navAlerts: 'Alert Center',
  navAirGround: 'Air-Ground',
  navAssets: 'Assets',
  navSolution: 'Solution',
  mainModules: 'Main Modules',
  mapRoute: 'Route',
  mapDrone: 'Drone',
  mapDog: 'Robot Dog',
  mapSensor: 'Sensor',
  mapAlert: 'Alert',
  waypoint: 'WP',
  inProgress: 'In progress',
  viewDesktop: 'Console',
  viewMobile: 'Mobile',
  mobileHome: 'Home',
  mobileAlerts: 'Alerts',
  mobileLive: 'Live',
  mobileDevices: 'Devices',
  mobileMore: 'Me',
  mobileGreeting: 'Field Security Assistant',
  mobileOpsSummary: 'Air-Ground · Kenya Ops',
  mobileOpenLive: 'Open Live View',
  mobileLiveTitle: 'Live Video & Intercom',
  mobileSelectFeed: 'Select Feed',
  mobileFeedDrone: 'Drone',
  mobileFeedDog: 'Robot Dog',
  mobileLiveBadge: 'LIVE',
  mobileLatency: 'Latency',
  mobileSignal: 'Signal',
  mobileBattery: 'Battery',
  mobileAltitude: 'Altitude',
  mobileSpeed: 'Speed',
  mobileOptical: 'Optical',
  mobileThermal: 'Thermal',
  mobileSplit: 'Split',
  mobileIntercom: 'Intercom',
  mobileChannel: 'Channel',
  mobilePtt: 'Hold to Talk',
  mobilePttHint: 'Release to end · via Starlink relay',
  mobileTalking: 'Talking…',
  mobileListening: 'Listening',
  mobileMute: 'Mute',
  mobileUnmute: 'Unmute',
  mobileSpeakerOn: 'Speaker On',
  mobileChatEmpty: 'No intercom yet. Hold the button below to speak.',
  mobileYou: 'You',
  mobileDeviceSaid: 'Device',
  mobileSiren: 'Siren',
  mobileSpotlight: 'Strobe',
  mobileSnapshot: 'Snapshot',
  mobileReturn: 'RTH / Charge',
  mobilePendingAlerts: 'Pending Alerts',
  mobileActiveUnits: 'Active Units',
  mobileQuickActions: 'Quick Actions',
  mobileActionDeterrence: 'Acoustic Deterrence',
  mobileActionDispatch: 'Dispatch Nearest Unit',
  mobileDemoNote: 'Video is a simulated live stream; intercom is local interaction demo.',
}

export const uiMessages: Record<Locale, UiMessages> = { zh, en }

export function statusLabel(ui: UiMessages, status: string) {
  const map: Record<string, string> = {
    pending: ui.statusPending,
    processing: ui.statusProcessing,
    resolved: ui.statusResolved,
    executing: ui.statusExecuting,
    success: ui.statusSuccess,
    online: ui.statusOnline,
    patrol: ui.statusPatrol,
    charging: ui.statusCharging,
    offline: ui.statusOffline,
    standby: ui.statusStandby,
  }
  return map[status] ?? status
}

export function formatTemplate(template: string, values: Record<string, string | number>) {
  return Object.entries(values).reduce(
    (text, [key, value]) => text.replace(`{${key}}`, String(value)),
    template,
  )
}
