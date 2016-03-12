import _ from 'underscore'
import ChangeFolderTask from './change-folder-task'
import ChangeLabelsTask from './change-labels-task'
import ChangeUnreadTask from './change-unread-task'
import ChangeStarredTask from './change-starred-task'
import AccountStore from '../stores/account-store'
import CategoryStore from '../stores/category-store'
import Thread from '../models/thread'
import Category from '../models/category'


const TaskFactory = {

  tasksForApplyingCategories({threads, categoriesToRemove = ()=>[], categoriesToAdd = ()=>[], taskDescription} = {}) {
    const byAccount = {}
    const tasks = []

    threads.forEach((thread)=> {
      if (!(thread instanceof Thread)) {
        throw new Error("tasksForApplyingCategories: `threads` must be instances of Thread")
      }
      const {accountId} = thread
      if (!byAccount[accountId]) {
        byAccount[accountId] = {
          categoriesToRemove: categoriesToRemove(accountId),
          categoriesToAdd: categoriesToAdd(accountId),
          threadsToUpdate: [],
        }
      }
      byAccount[accountId].threadsToUpdate.push(thread)
    })

    _.each(byAccount, (data, accountId) => {
      const catsToAdd = data.categoriesToAdd;
      const catsToRemove = data.categoriesToRemove;
      const threadsToUpdate = data.threadsToUpdate;
      const account = AccountStore.accountForId(accountId);
      if (!(catsToAdd instanceof Array)) {
        throw new Error("tasksForApplyingCategories: `categoriesToAdd` must return an array of Categories")
      }
      if (!(catsToRemove instanceof Array)) {
        throw new Error("tasksForApplyingCategories: `categoriesToRemove` must return an array of Categories")
      }

      if (account.usesFolders()) {
        if (catsToAdd.length === 0) return;
        if (catsToAdd.length > 1) {
          throw new Error("tasksForApplyingCategories: `categoriesToAdd` must return a single `Category` (folder) for Exchange accounts")
        }
        const folder = catsToAdd[0]
        if (!(folder instanceof Category)) {
          throw new Error("tasksForApplyingCategories: `categoriesToAdd` must return a Category")
        }

        tasks.push(new ChangeFolderTask({
          folder,
          threads: threadsToUpdate,
          taskDescription,
        }))
      } else {
        const labelsToAdd = catsToAdd
        const labelsToRemove = catsToRemove
        if (labelsToAdd.length === 0 && labelsToRemove.length === 0) return;

        tasks.push(new ChangeLabelsTask({
          threads: threadsToUpdate,
          labelsToRemove,
          labelsToAdd,
          taskDescription,
        }))
      }
    })

    return tasks;
  },

  taskForApplyingCategory({threads, category}) {
    const tasks = TaskFactory.tasksForApplyingCategories({
      threads,
      categoriesToAdd: () => [category],
    })

    if (tasks.length > 1) {
      throw new Error("taskForApplyingCategory: Threads must be from the same account.")
    }

    return tasks[0];
  },

  taskForRemovingCategory({threads, category}) {
    const tasks = TaskFactory.tasksForApplyingCategories({
      threads,
      categoriesToRemove: () => [category],
    })

    if (tasks.length > 1) {
      throw new Error("taskForRemovingCategory: Threads must be from the same account.")
    }

    return tasks[0];
  },

  tasksForMarkingAsSpam({threads}) {
    return TaskFactory.tasksForApplyingCategories({
      threads,
      categoriesToAdd: (accountId) => [CategoryStore.getSpamCategory(accountId)],
    })
  },

  tasksForArchiving({threads}) {
    return TaskFactory.tasksForApplyingCategories({
      threads,
      categoriesToRemove: (accountId) => [
        CategoryStore.getInboxCategory(accountId),
      ],
      categoriesToAdd: (accountId) => [CategoryStore.getArchiveCategory(accountId)],
    })
  },

  tasksForMovingToTrash({threads}) {
    return TaskFactory.tasksForApplyingCategories({
      threads,
      categoriesToAdd: (accountId) => [CategoryStore.getTrashCategory(accountId)],
    })
  },

  taskForInvertingUnread({threads}) {
    const unread = _.every(threads, (t) => _.isMatch(t, {unread: false}))
    return new ChangeUnreadTask({threads, unread})
  },

  taskForInvertingStarred({threads}) {
    const starred = _.every(threads, (t) => _.isMatch(t, {starred: false}))
    return new ChangeStarredTask({threads, starred})
  },
}

export default TaskFactory
