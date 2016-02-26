/** @babel */
import moment from 'moment';
import _ from 'underscore';
import {
  Actions,
  Thread,
  Category,
  CategoryStore,
  DatabaseStore,
  AccountStore,
  SyncbackCategoryTask,
  TaskQueueStatusStore,
  TaskFactory,
  DateUtils,
} from 'nylas-exports';
import {SNOOZE_CATEGORY_NAME, DATE_FORMAT_SHORT} from './snooze-constants'

export function snoozeMessage(snoozeDate) {
  let message = 'Snoozed'
  if (snoozeDate) {
    let dateFormat = DATE_FORMAT_SHORT
    const date = moment(snoozeDate)
    const now = moment()
    const hourDifference = moment.duration(date.diff(now)).asHours()

    if (hourDifference < 24) {
      dateFormat = dateFormat.replace('MMM D, ', '');
    }
    if (date.minutes() === 0) {
      dateFormat = dateFormat.replace(':mm', '');
    }

    message += ` until ${DateUtils.format(date, dateFormat)}`;
  }
  return message;
}

export function createSnoozeCategory(accountId, name = SNOOZE_CATEGORY_NAME) {
  const category = new Category({
    displayName: name,
    accountId: accountId,
  })
  const task = new SyncbackCategoryTask({category})

  Actions.queueTask(task)
  return TaskQueueStatusStore.waitForPerformRemote(task).then(()=>{
    return DatabaseStore.findBy(Category, {clientId: category.clientId})
    .then((updatedCat)=> {
      if (updatedCat && updatedCat.isSavedRemotely()) {
        return Promise.resolve(updatedCat)
      }
      return Promise.reject(new Error('Could not create Snooze category'))
    })
  })
}


export function whenCategoriesReady() {
  const categoriesReady = ()=> CategoryStore.categories().length > 0
  if (!categoriesReady()) {
    return new Promise((resolve)=> {
      const unsubscribe = CategoryStore.listen(()=> {
        if (categoriesReady()) {
          unsubscribe()
          resolve()
        }
      })
    })
  }
  return Promise.resolve()
}


export function getSnoozeCategory(accountId, categoryName = SNOOZE_CATEGORY_NAME) {
  return whenCategoriesReady()
  .then(()=> {
    const allCategories = CategoryStore.categories(accountId)
    const category = _.findWhere(allCategories, {displayName: categoryName})
    if (category) {
      return Promise.resolve(category);
    }
    return createSnoozeCategory(accountId, categoryName)
  })
}


export function getSnoozeCategoriesByAccount(accounts = AccountStore.accounts()) {
  const categoriesByAccountId = {}
  accounts.forEach(({id})=> {
    if (categoriesByAccountId[id] != null) return;
    categoriesByAccountId[id] = getSnoozeCategory(id)
  })
  return Promise.props(categoriesByAccountId)
}


export function groupProcessedThreadsByAccountId(categoriesByAccountId, threads) {
  return DatabaseStore.modelify(Thread, _.pluck(threads, 'clientId')).then((updatedThreads)=> {
    const threadsByAccountId = {}
    updatedThreads.forEach((thread)=> {
      const accId = thread.accountId
      if (!threadsByAccountId[accId]) {
        threadsByAccountId[accId] = {
          updatedThreads: [thread],
          snoozeCategoryId: categoriesByAccountId[accId].serverId,
          returnCategoryId: CategoryStore.getInboxCategory(accId).serverId,
        }
      } else {
        threadsByAccountId[accId].updatedThreads.push(thread);
      }
    });
    return Promise.resolve(threadsByAccountId);
  })
}


export function moveThreads(threads, categoriesByAccountId, {snooze, description} = {}) {
  const inbox = CategoryStore.getInboxCategory
  const snoozeCat = (accId)=> categoriesByAccountId[accId]
  const tasks = TaskFactory.tasksForApplyingCategories({
    threads,
    categoriesToRemove: snooze ? inbox : snoozeCat,
    categoryToAdd: snooze ? snoozeCat : inbox,
    taskDescription: description,
  })

  Actions.queueTasks(tasks)
  const promises = tasks.map(task => TaskQueueStatusStore.waitForPerformRemote(task))
  // Resolve with the updated threads
  return (
    Promise.all(promises).then(()=> {
      return groupProcessedThreadsByAccountId(categoriesByAccountId, threads)
    })
  )
}


export function moveThreadsToSnooze(threads, snoozeDate) {
  return getSnoozeCategoriesByAccount()
  .then((categoriesByAccountId)=> {
    const description = snoozeMessage(snoozeDate)
    return moveThreads(threads, categoriesByAccountId, {snooze: true, description})
  })
}


export function moveThreadsFromSnooze(threads) {
  return getSnoozeCategoriesByAccount()
  .then((categoriesByAccountId)=> {
    const description = 'Unsnoozed';
    return moveThreads(threads, categoriesByAccountId, {snooze: false, description})
  })
}
